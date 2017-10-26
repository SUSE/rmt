require 'typhoeus'
require 'tempfile'
require 'fileutils'
require 'fiber'
require 'rmt'
require 'rmt/http_request'

class RMT::Downloader

  class Exception < RuntimeError
  end

  KNOWN_HASH_FUNCTIONS = %i[MD5 SHA1 SHA256 SHA384 SHA512].freeze

  attr_accessor :repository_url, :local_path, :concurrency, :logger, :auth_token

  def initialize(repository_url:, local_path:, auth_token: nil, logger: nil)
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    @repository_url = repository_url
    @local_path = local_path
    @concurrency = 4
    @auth_token = auth_token
    @logger = logger || Logger.new('/dev/null')
  end

  def download(remote_file, checksum_type = nil, checksum_value = nil)
    local_file = make_local_path(remote_file)

    request_fiber = Fiber.new do
      make_request(remote_file, local_file, request_fiber, checksum_type, checksum_value)
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

  protected

  def process_queue
    # Skip over files that already exist
    begin
      queue_item = @queue.shift
      return unless queue_item

      remote_file = queue_item.location
      local_file = make_local_path(remote_file)
    end while File.exist?(local_file) # rubocop:disable Lint/Loop

    # The request is wrapped into a fiber for exception handling
    request_fiber = Fiber.new do
      begin
        make_request(remote_file, local_file, request_fiber, queue_item[:checksum_type], queue_item[:checksum])
      rescue RMT::Downloader::Exception => e
        @logger.warn("× #{File.basename(local_file)} - #{e}")
      ensure
        process_queue
      end
    end

    @hydra.queue(request_fiber.resume)
  end

  def verify_checksum(filename, checksum_type, checksum_value)
    hash_function = checksum_type.gsub(/\W/, '').upcase.to_sym
    hash_function = :SHA1 if (hash_function == :SHA)

    unless (KNOWN_HASH_FUNCTIONS.include? hash_function)
      raise RMT::Downloader::Exception.new("Unknown hash function #{checksum_type}")
    end

    digest = Digest.const_get(hash_function).file(filename)

    raise RMT::Downloader::Exception.new('Checksum doesn\'t match') unless (checksum_value == digest.to_s)
  end

  def make_request(remote_file, local_file, request_fiber, checksum_type = nil, checksum_value = nil)
    uri = URI.join(@repository_url, remote_file)
    uri.query = @auth_token if @auth_token

    downloaded_file = Tempfile.new('rmt', Dir.tmpdir, mode: File::BINARY, encoding: 'ascii-8bit')

    request = RMT::FiberRequest.new(
      uri.to_s,
      followlocation: true,
      download_path: downloaded_file,
      request_fiber: request_fiber
    )

    begin
      response = request.receive_headers
      if (URI(uri).scheme != 'file' && response.code != 200)
        raise RMT::Downloader::Exception.new("#{remote_file} - HTTP request failed with code #{response.code}")
      end
    rescue StandardError => e
      downloaded_file.unlink
      Fiber.yield # yield, so that on_body callback can be invoked
      raise e
    end

    begin
      response = request.receive_body
      if (response.return_code && response.return_code != :ok)
        raise RMT::Downloader::Exception.new("#{remote_file} - return code #{response.return_code}")
      end

      downloaded_file.close

      verify_checksum(downloaded_file.path, checksum_type, checksum_value) if (checksum_type && checksum_value)
    rescue StandardError => e
      downloaded_file.unlink
      raise e
    end

    FileUtils.mv(downloaded_file.path, local_file)
    File.chmod(0o644, local_file)

    @logger.info("↓ #{File.basename(local_file)}")
  end

  def make_local_path(remote_file)
    filename = File.join(@local_path, remote_file.gsub(/\.\./, '__'))
    dirname = File.dirname(filename)

    FileUtils.mkdir_p(dirname)

    filename
  end

end
