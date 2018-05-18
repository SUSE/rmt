require 'typhoeus'
require 'rmt/config'

class RMT::HttpRequest < Typhoeus::Request

  def set_defaults
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    Typhoeus::Config.verbose = Settings.try(:http_client).try(:verbose)

    super

    options[:proxy] = Settings.try(:http_client).try(:proxy)
    options[:proxyauth] = Settings.try(:http_client).try(:proxy_auth) ? Settings.try(:http_client).try(:proxy_auth).to_sym : :any

    if Settings.try(:http_client).try(:proxy_user) && Settings.try(:http_client).try(:proxy_password)
      options[:proxyuserpwd] = "#{Settings.http_client.proxy_user}:#{Settings.http_client.proxy_password}"
    end
  end

end
