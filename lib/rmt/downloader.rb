module RMT
end

require 'typhoeus'
require 'tempfile'
require 'fileutils'

class RMT::Downloader

  class Exception < RuntimeError
  end

  KNOWN_HASH_FUNCTIONS = %i(MD5 SHA1 SHA256 SHA384 SHA512).freeze

  attr_accessor :repository_url, :local_path, :concurrency, :logger

  def initialize(repository_url, local_path, logger = nil)
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    @repository_url = repository_url
    @local_path = local_path
    @concurrency = 4
    @logger = logger || Logger.new('/dev/null')
  end

  def verify_checksum(filename, checksum_type, checksum_value)
    hash_function = checksum_type.gsub(/\W/, '').upcase.to_sym
    unless (KNOWN_HASH_FUNCTIONS.include? hash_function)
      raise Exception.new("Unknown hash function #{checksum_type}")
    end

    digest = Digest.const_get(hash_function).file(filename)

    raise Exception.new('Checksum doesn\'t match') unless (checksum_value == digest.to_s)
  end

  def download(remote_file, checksum_type = nil, checksum_value = nil)
    local_file = make_local_path(remote_file)
    make_request(remote_file, local_file, checksum_type, checksum_value).run
    local_file
  end

  def download_multi(files)
    @queue = files
    @hydra = Typhoeus::Hydra.new(max_concurrency: @concurrency)

    @concurrency.times { download_one }

    loop do
      error = false
      begin
        @hydra.run
      rescue RMT::Downloader::Exception => e
        @logger.info("E #{e}")
        download_one
        error = true
      end
      break unless error
    end
  end

  protected

  def download_one
    remote_file = local_file = queue_item = nil

    loop do
      queue_item = @queue.shift
      return unless queue_item

      remote_file = queue_item.location
      local_file = make_local_path(remote_file)

      already_downloaded = File.exist?(local_file)
      break unless already_downloaded
    end

    klass = self
    request = make_request(remote_file, local_file, queue_item[:checksum_type], queue_item[:checksum]) do
      klass.download_one
    end

    @hydra.queue(request)
  end

  def make_local_path(remote_file)
    filename = File.join(@local_path, remote_file)
    dirname = File.dirname(filename)

    FileUtils.mkdir_p(dirname)

    filename
  end

  def make_request(remote_file, local_file, checksum_type, checksum_value, &complete_callback)
    uri = URI.join(@repository_url, remote_file)
    downloaded_file = Tempfile.new('rmt')

    request = Typhoeus::Request.new(uri.to_s, followlocation: true)
    request.on_headers do |response|
      if (URI(uri).scheme != 'file' and response.code != 200)
        downloaded_file.unlink
        raise Exception.new("#{remote_file} - HTTP request failed with code #{response.code}")
      end
    end

    request.on_body do |chunk|
      downloaded_file.write(chunk)
    end

    request.on_complete do |response|
      next if (response.return_code and response.return_code != :ok)

      downloaded_file.close

      begin
        verify_checksum(downloaded_file.path, checksum_type, checksum_value) if (checksum_type and checksum_value)
        FileUtils.mv(downloaded_file.path, local_file)
      ensure
        downloaded_file.unlink
      end

      @logger.info("D #{File.basename(local_file)}")

      yield if complete_callback
    end
    request
  end

end
