# Wraps Typhoeus request in a fiber, resumes the fiber in callbacks.
class RMT::FiberRequest < RMT::HttpRequest
  attr_accessor :base_url, :download_path, :remote_file

  def initialize(base_url, download_path:, request_fiber:, **options)
    @base_url = base_url
    @download_path = download_path
    @request_fiber = request_fiber
    @remote_file = base_url.split('?').first

    super(base_url, options)

    on_body do |chunk|
      next :abort if @download_path.closed?
      @download_path.write(chunk)
    end
    # Resume the fiber from on_complete only. Ethon calls on_complete from
    # Multi#check, after curl_multi_perform returns. No libcurl frame is live then.
    # An on_headers resume runs inside the libcurl write callback and corrupts
    # the heap. See bsc#1276939.
    on_complete { |response| @request_fiber.resume(response) if @request_fiber.alive? }
  end

  def receive_body
    response = read_body

    if (response.return_code && response.return_code != :ok)
      raise 'Error while processing the response.'
    end

    @download_path.close
    response
  rescue StandardError
    @download_path.unlink
    response
  end

  protected

  # helper method for specs
  def read_body
    # The first yield gives this request to RMT::Downloader#create_fiber_request.
    # The on_complete resume makes the yield return the response.
    Fiber.yield(self)
  end

end
