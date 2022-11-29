class RMT::Downloader::Exception < RuntimeError
  attr_accessor :http_code, :response

  def initialize(message, response: nil)
    @response = response
    @http_code = response&.code
    super(message)
  end

  def self.raise_request_error(remote_file, response, logger)
    logger.debug <<~DEBUG.chomp
    #{_('Request error:')}
      #{_('Request URL')}: #{response.effective_url}
      #{_('Response HTTP status code')}: #{response.code}
      #{_('Response body')}: #{response.body.presence || "''"}
      #{_('Response headers')}: #{flatten_string(response.response_headers.presence)}
      #{_('curl return code')}: #{response.return_code.presence || "''"}
      #{_('curl return message')}: #{response.return_message.presence || "''"}
    DEBUG

    message = _("%{file} - request failed with HTTP status code %{code}, return code '%{return_code}'") %
      { file: remote_file, code: response.code, return_code: response.return_code }

    raise RMT::Downloader::Exception.new(message, response: response)
  end

  def self.flatten_string(str)
    return '' if str.blank?

    str.lines.map(&:strip).map(&:presence).compact.join('; ')
  end

end
