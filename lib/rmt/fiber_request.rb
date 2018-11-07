# Wraps Typhoeus request in a fiber, resumes the fiber in callbacks.
class RMT::FiberRequest < RMT::HttpRequest
  attr_accessor :base_url, :download_path, :remote_file

  def initialize(base_url, download_path:, request_fiber:, remote_file:, **options)
    @base_url = base_url
    @download_path = download_path
    @request_fiber = request_fiber
    @remote_file = remote_file

    super(base_url, options)

    on_headers { |response| @request_fiber.resume(response) }
    on_body do |chunk|
      next :abort if @download_path.closed?
      @download_path.write(chunk)
    end
    on_complete do |response|
      @request_fiber.resume(response) unless response.return_code == :ok # otherwise skips on_headers resume when the request has failed
      @request_fiber.resume(response) if @request_fiber.alive?
    end
  end

  def receive_headers
    Fiber.yield(self)
  end

  def receive_body
    response = read_body

    if (response.return_code && response.return_code != :ok)
      raise RMT::Downloader::Exception.new(_('%{file} - return code %{code}') % { file: @remote_file, code: response.return_code })
    end

    @download_path.close
    response
  rescue StandardError => e
    @download_path.unlink
    raise e
  end

  protected

  # helper method for specs
  def read_body
    Fiber.yield
  end

end
