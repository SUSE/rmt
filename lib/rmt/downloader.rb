require 'typhoeus'
require 'tempfile'
require 'fileutils'
require 'fiber'
require 'rmt'
require 'rmt/config'
require 'rmt/fiber_request'
require 'rmt/deduplicator'

class RMT::Downloader
  class Exception < RuntimeError
    attr_reader :http_code

    def initialize(message, http_code = nil)
      @http_code = http_code
      super(message)
    end
  end

  attr_accessor :concurrency, :logger, :auth_token

  def initialize(logger:, auth_token: nil, track_files: true)
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    @concurrency = 4
    @auth_token = auth_token
    @logger = logger
    @track_files = track_files
    @queue = []
  end

  def download(file_reference)
    local_filenames = []
    fiber_request = create_fiber_request(
      local_filenames,
      file_reference
    )
    fiber_request.run
    local_filenames.first
  end

  def download_multi(files, ignore_errors: false)
    @queue = files
    @hydra = Typhoeus::Hydra.new(max_concurrency: @concurrency)

    local_filenames = []
    failed_downloads = ignore_errors ? [] : nil
    @concurrency.times { process_queue(local_filenames, failed_downloads) }

    @hydra.run
    failed_downloads
  end

  protected

  # Creates a fiber that wraps RMT::FiberRequest and runs it, returning the RMT::FiberRequest object.
  # @param [Array] local_filenames array of paths to downloaded files, passed by reference
  # @param [RMT::Mirror::FileReference] PORO with all file metadata attributes and paths (remote, local, cache)
  # @param [Array] failed_downloads array of remote files that have failed downloads, passed by reference, prevents from raising RMT::Downloader exceptions
  # @return [RMT::FiberRequest] a request that can be run individually or with Typhoeus::Hydra
  def create_fiber_request(local_filenames, file_reference, failed_downloads: nil)
    make_file_dir(file_reference.local_path)

    request_fiber = Fiber.new do
      begin
        # make_request will call Fiber.yield on this fiber (request_fiber), returning the request object
        # this fiber will be resumed by on_body callback once the request is executed
        response = make_request(file_reference, request_fiber)

        if (response.code == 304)
          copy_from_cache(file_reference)
        else
          finalize_download(response.request, file_reference)
        end

        local_filenames << file_reference.local_path
      rescue RMT::Downloader::Exception, RMT::ChecksumVerifier::Exception => e
        unless failed_downloads
          # Clean up downloads queued in Ethon::Multi and @queue
          if @hydra
            @queue = []
            @hydra.multi.easy_handles.each do |handle|
              @hydra.multi.delete(handle)
            end
          end

          raise(e)
        end

        @logger.warn("× #{File.basename(file_reference.local_path)} - #{e}")
        failed_downloads << file_reference.local_path
      ensure
        process_queue(local_filenames, failed_downloads)
      end
    end

    request_fiber.resume
  end

  def process_queue(local_filenames, failed_downloads = nil)
    queue_item = @queue.shift
    return unless queue_item

    @hydra.queue(
      create_fiber_request(
        local_filenames,
        queue_item,
        failed_downloads: failed_downloads
      )
    )
  end

  def make_request(file, request_fiber)
    uri = request_uri(file)

    downloaded_file = Tempfile.new('rmt', Dir.tmpdir, mode: File::BINARY, encoding: 'ascii-8bit')

    headers = {}
    headers['If-Modified-Since'] = file.cache_timestamp if file.cache_timestamp

    request = RMT::FiberRequest.new(
      uri.to_s,
      download_path: downloaded_file,
      request_fiber: request_fiber,
      followlocation: true,
      headers: headers
    )

    request.receive_headers
    request.receive_body
  end

  def request_uri(file)
    uri = URI.join(file.remote_path)
    uri.query = @auth_token if (@auth_token && uri.scheme != 'file')

    if URI(uri).scheme == 'file' && !File.exist?(uri.path)
      raise RMT::Downloader::Exception.new(_('%{file} - File does not exist') % { file: file.remote_path })
    end

    uri.to_s
  end

  def copy_from_cache(file)
    FileUtils.cp(file.cache_path, file.local_path, preserve: true) unless (file.cache_path == file.local_path)
    @logger.info("→ #{File.basename(file.local_path)}")
  end

  def finalize_download(request, file)
    if (URI(request.base_url).scheme != 'file' && request.response.code != 200)
      raise RMT::Downloader::Exception.new(
        _('%{file} - HTTP request failed with code %{code}') % {
          file: request.remote_file,
          code: request.response.code
        },
        request.response.code
      )
    end

    handle_checksum_verification!(file.checksum_type, file.checksum, request.download_path)

    FileUtils.mv(request.download_path.path, file.local_path)
    File.chmod(0o644, file.local_path)

    if @track_files && file.local_path.match?(/\.(rpm|drpm)$/)
      DownloadedFile.track_file(checksum: file.checksum,
                                checksum_type: file.checksum_type,
                                local_path: file.local_path,
                                size: File.size(file.local_path))
    end

    @logger.info("↓ #{File.basename(file.local_path)}")
  rescue StandardError => e
    request.download_path.unlink
    raise e
  end

  def handle_checksum_verification!(checksum_type, checksum_value, download_path)
    return unless (checksum_type && checksum_value)

    unless RMT::ChecksumVerifier.match_checksum?(checksum_type, checksum_value, download_path)
      raise RMT::Downloader::Exception.new(_("Checksum doesn't match"))
    end
  end

  def make_file_dir(file_path)
    dirname = File.dirname(file_path)

    FileUtils.mkdir_p(dirname)
  end
end
