module RMT
end

class RMT::Downloader

  KNOWN_HASH_FUNCTIONS = %i(MD5 SHA1 SHA256 SHA384 SHA512).freeze

  attr_accessor :concurrency

  def initialize(repository_url, local_path, logger)
    @repository_url = repository_url
    @local_path = local_path
    @concurrency = 4
    @logger = logger || Logger.new('/dev/null')
  end

  def verify_checksum(filename, checksum_type, checksum_value)
    hash_function = checksum_type.gsub(/\W/, '').upcase.to_sym
    unless (KNOWN_HASH_FUNCTIONS.include? hash_function)
      raise "Unknown hash function #{checksum_type}"
    end

    digest = Digest.const_get(hash_function).file(filename)

    raise 'Checksum doesn\'t match!' unless (checksum_value == digest.to_s)

    @logger.debug("D #{File.basename(filename)} - OK!")
  end

  def download(remote_file, checksum_type = nil, checksum_value = nil)
    filename = make_path(remote_file)
    make_request(remote_file, filename).run

    if (checksum_type and checksum_value)
      verify_checksum(filename, checksum_type, checksum_value)
    end

    filename
  end

  def download_multi(files)
    @queue = files
    @hydra = Typhoeus::Hydra.new(max_concurrency: @concurrency)

    @concurrency.times { download_one }

    @hydra.run
  end

  protected

  def download_one
    queue_item = @queue.shift
    return unless queue_item

    remote_file = queue_item.location
    filename = make_path(remote_file)

    klass = self
    request = make_request(remote_file, filename) do
      klass.verify_checksum(filename, queue_item.checksum_type, queue_item.checksum)
      klass.download_one
    end

    @hydra.queue(request)
  end

  def make_path(remote_file)
    filename = File.join(@local_path, remote_file)
    dirname = File.dirname(filename)

    FileUtils.mkdir_p(dirname)

    filename
  end

  def make_request(remote_file, filename, &complete_callback)
    uri = URI.join(@repository_url, remote_file).to_s
    downloaded_file = File.open(filename, 'wb')

    request = Typhoeus::Request.new(uri, followlocation: true)
    request.on_headers do |response|
      raise 'Request failed' if response.code != 200
    end
    request.on_body do |chunk|
      downloaded_file.write(chunk)
    end
    request.on_complete do
      downloaded_file.close
      yield if complete_callback
    end
    request
  end

end
