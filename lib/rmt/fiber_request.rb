# Wraps Typhoeus request in a fiber, resumes the fiber in callbacks.
class RMT::FiberRequest < RMT::HttpRequest

  def initialize(base_url, options = {})
    raise 'Missing download_path option' unless (options[:download_path])
    raise 'Missing request_fiber option' unless (options[:request_fiber])

    @download_path = options[:download_path]
    @request_fiber = options[:request_fiber]
    options.delete(:download_path)
    options.delete(:request_fiber)

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
    Fiber.yield(self)
  end

  def receive_body
    Fiber.yield
  end

end
