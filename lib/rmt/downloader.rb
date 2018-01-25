require 'typhoeus'
require 'tempfile'
require 'fileutils'
require 'fiber'
require 'rmt'
require 'rmt/config'
require 'rmt/fiber_request'
require 'rmt/deduplicator'

class RMT::Downloader

  class Exception < RuntimeError; end
  class NotModifiedException < RuntimeError; end

  attr_accessor :repository_url, :local_path, :concurrency, :logger, :auth_token, :cache_path

  def initialize(repository_url:, local_path:, auth_token: nil, logger: nil, cache_path: nil)
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    @repository_url = repository_url
    @local_path = local_path
    @concurrency = 4
    @auth_token = auth_token
    @logger = logger || Logger.new('/dev/null')
    @cache_path = cache_path
  end

  def download(remote_file, checksum_type: nil, checksum_value: nil)
    local_file = self.class.make_local_path(@local_path, remote_file)

    cache_timestamp = nil
    if @cache_path
      raise 'Cache path not set!' unless @cache_path
      cache_file = File.join(@cache_path, remote_file)
      cache_timestamp = File.mtime(cache_file).utc.httpdate if File.exist?(cache_file)
    end

    request_fiber = Fiber.new do
      response = make_request(remote_file, request_fiber, cache_timestamp)

      if (response.code == 304)
        copy_from_cache(cache_file, local_file)
      else
        finalize_download(response.request, local_file, checksum_type, checksum_value)
      end
    end

    request_fiber.resume.run

    local_file
  end

  def download_multi(files)
    @queue = files
    @hydra = Typhoeus::Hydra.new(max_concurrency: @concurrency)

    @concurrency.times { process_queue }

    @hydra.run
  end

  def self.make_local_path(root_path, remote_file)
    filename = File.join(root_path, remote_file.gsub(/\.\./, '__'))
    dirname = File.dirname(filename)

    FileUtils.mkdir_p(dirname)

    filename
  end

  protected

  def process_queue
    queue_item = @queue.shift
    return unless queue_item
    remote_file = queue_item.location
    local_file = self.class.make_local_path(@local_path, remote_file)

    # The request is wrapped into a fiber for exception handling
    request_fiber = Fiber.new do
      begin
        response = make_request(remote_file, request_fiber)
        finalize_download(response.request, local_file, queue_item[:checksum_type], queue_item[:checksum])
      rescue RMT::Downloader::Exception => e
        @logger.warn("× #{File.basename(local_file)} - #{e}")
      ensure
        process_queue
      end
    end

    @hydra.queue(request_fiber.resume)
  end

  def make_request(remote_file, request_fiber, cache_timestamp = nil)
    uri = URI.join(@repository_url, remote_file)
    uri.query = @auth_token if (@auth_token && uri.scheme != 'file')

    if URI(uri).scheme == 'file' && !File.exist?(uri.path)
      raise RMT::Downloader::Exception.new("#{remote_file} - File does not exist")
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

  def copy_from_cache(cache_file, local_file)
    FileUtils.cp(cache_file, local_file)
    @logger.info("→ #{File.basename(local_file)}")
    local_file
  end

  def finalize_download(request, local_file, checksum_type = nil, checksum_value = nil)
    if (URI(request.base_url).scheme != 'file' && request.response.code != 200)
      raise RMT::Downloader::Exception.new("#{request.remote_file} - HTTP request failed with code #{request.response.code}")
    end

    RMT::ChecksumVerifier.verify_checksum(checksum_type, checksum_value, request.download_path) if (checksum_type && checksum_value)

    FileUtils.mv(request.download_path.path, local_file)
    File.chmod(0o644, local_file)

    ::RMT::Deduplicator.add_local(local_file, checksum_type, checksum_value)

    @logger.info("↓ #{File.basename(local_file)}")
  rescue StandardError => e
    request.download_path.unlink
    raise e
  end

end
