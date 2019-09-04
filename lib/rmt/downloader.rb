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

  attr_accessor :repository_url, :destination_dir, :concurrency, :logger, :auth_token, :cache_dir

  def initialize(repository_url:, destination_dir:, logger:, auth_token: nil, cache_dir: nil, save_for_dedup: true)
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    @repository_url = repository_url
    @destination_dir = destination_dir
    @concurrency = 4
    @auth_token = auth_token
    @logger = logger
    @cache_dir = cache_dir
    @save_for_dedup = save_for_dedup
    @queue = []
  end

  def download(remote_file, checksum_type: nil, checksum_value: nil)
    local_filenames = []
    fiber_request = create_fiber_request(
      local_filenames,
      remote_file,
      checksum_type: checksum_type,
      checksum_value: checksum_value
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

  def self.make_local_path(root_path, remote_file)
    filename = File.join(root_path, remote_file.gsub(/\.\./, '__'))
    dirname = File.dirname(filename)

    FileUtils.mkdir_p(dirname)

    filename
  end

  protected

  def get_cache_timestamp(filename)
    File.mtime(filename).utc.httpdate if File.exist?(filename)
  end

  # Creates a fiber that wraps RMT::FiberRequest and runs it, returning the RMT::FiberRequest object.
  # @param [Array] local_filenames array of paths to downloaded files, passed by reference
  # @param [String] remote_file path of the remote file relative to @repository_url
  # @param [String] checksum_type expected remote file checksum type
  # @param [String] checksum_value expected remote file checksum value
  # @param [Array] failed_downloads array of remote files that have failed downloads, passed by reference, prevents from raising RMT::Downloader exceptions
  # @return [RMT::FiberRequest] a request that can be run individually or with Typhoeus::Hydra
  def create_fiber_request(local_filenames, remote_file, checksum_type: nil, checksum_value: nil, failed_downloads: nil)
    local_filename = self.class.make_local_path(@destination_dir, remote_file)

    request_fiber = Fiber.new do
      begin
        cache_timestamp = nil
        if @cache_dir
          cache_filename = File.join(@cache_dir, remote_file)
          cache_timestamp = get_cache_timestamp(cache_filename)
        end

        # make_request will call Fiber.yield on this fiber (request_fiber), returning the request object
        # this fiber will be resumed by on_body callback once the request is executed
        response = make_request(remote_file, request_fiber, cache_timestamp)

        if (response.code == 304)
          copy_from_cache(cache_filename, local_filename)
        else
          finalize_download(response.request, local_filename, checksum_type, checksum_value)
        end

        local_filenames << local_filename
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

        @logger.warn("× #{File.basename(local_filename)} - #{e}")
        failed_downloads << remote_file
      ensure
        process_queue(local_filenames, failed_downloads)
      end
    end

    request_fiber.resume
  end

  def process_queue(local_filenames, failed_downloads = nil)
    queue_item = @queue.shift
    return unless queue_item

    if queue_item.is_a?(String)
      @hydra.queue(create_fiber_request(local_filenames, queue_item, failed_downloads: failed_downloads))
    else
      @hydra.queue(
        create_fiber_request(
          local_filenames,
          queue_item.location,
          checksum_type: queue_item.checksum_type,
          checksum_value: queue_item.checksum,
          failed_downloads: failed_downloads
        )
      )
    end
  end

  def make_request(remote_file, request_fiber, cache_timestamp = nil)
    uri = URI.join(@repository_url, remote_file)
    uri.query = @auth_token if (@auth_token && uri.scheme != 'file')

    if URI(uri).scheme == 'file' && !File.exist?(uri.path)
      raise RMT::Downloader::Exception.new(_('%{file} - File does not exist') % { file: remote_file })
    end

    downloaded_file = Tempfile.new('rmt', Dir.tmpdir, mode: File::BINARY, encoding: 'ascii-8bit')

    headers = {}
    headers['If-Modified-Since'] = cache_timestamp if cache_timestamp

    request = RMT::FiberRequest.new(
      uri.to_s,
      download_path: downloaded_file,
      request_fiber: request_fiber,
      remote_file: remote_file,
      followlocation: true,
      headers: headers
    )

    request.receive_headers
    request.receive_body
  end

  def copy_from_cache(cache_filename, local_filename)
    FileUtils.cp(cache_filename, local_filename, preserve: true) unless (cache_filename == local_filename)
    @logger.info("→ #{File.basename(local_filename)}")
    local_filename
  end

  def finalize_download(request, local_file, checksum_type = nil, checksum_value = nil)
    if (URI(request.base_url).scheme != 'file' && request.response.code != 200)
      raise RMT::Downloader::Exception.new(
        _('%{file} - HTTP request failed with code %{code}') % { file: request.remote_file, code: request.response.code },
        request.response.code
      )
    end

    RMT::ChecksumVerifier.verify_checksum(checksum_type, checksum_value, request.download_path) if (checksum_type && checksum_value)

    FileUtils.mv(request.download_path.path, local_file)
    File.chmod(0o644, local_file)

    ::RMT::Deduplicator.add_local(local_file, checksum_type, checksum_value) if @save_for_dedup

    @logger.info("↓ #{File.basename(local_file)}")
  rescue StandardError => e
    request.download_path.unlink
    raise e
  end

end
