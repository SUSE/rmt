# Wraps Typhoeus request in a fiber, resumes the fiber in callbacks.
class RMT::FiberRequest < RMT::HttpRequest

  def initialize(base_url, options = {})
    raise 'Missing download_path option' unless (options[:download_path])
    raise 'Missing request_fiber option' unless (options[:request_fiber])

    @base_url = base_url
    @download_path = options[:download_path]
    @request_fiber = options[:request_fiber]
    @remote_file = options[:remote_file]
    options.delete(:download_path)
    options.delete(:request_fiber)
    options.delete(:remote_file)

    super(base_url, options)

    on_headers { |response| @request_fiber.resume(response) }
    on_body do |chunk|
      next :abort if @download_path.closed?
      @download_path.write(chunk)
    end
    on_complete do |response|
      @request_fiber.resume(response) if @request_fiber.alive?
    end
  end

  def receive_headers
    response = Fiber.yield(self)
    if (URI(@base_url).scheme != 'file' && response.code != 200)
      raise RMT::Downloader::Exception.new("#{@remote_file} - HTTP request failed with code #{response.code}")
    end
  rescue StandardError => e
    @download_path.unlink
    Fiber.yield # yield, so that on_body callback can be invoked
    raise e
  end

  def receive_body
    response = read_body

    if (response.return_code && response.return_code != :ok)
      raise RMT::Downloader::Exception.new("#{@remote_file} - return code #{response.return_code}")
    end

    @download_path.close
  end

  protected

  # helper method for specs
  def read_body
    Fiber.yield
  end

end
