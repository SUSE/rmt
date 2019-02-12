require 'typhoeus'
require 'rmt/config'

class RMT::HttpRequest < Typhoeus::Request

  def set_defaults
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    Typhoeus::Config.verbose = RMT::Config.http_client.verbose

    super

    options[:proxy] = RMT::Config.http_client.proxy

    options[:proxyauth] = RMT::Config.http_client.proxy_auth ? RMT::Config.http_client.proxy_auth.to_sym : :any

    if RMT::Config.http_client.proxy_user && RMT::Config.http_client.proxy_password
      options[:proxyuserpwd] = "#{RMT::Config.http_client.proxy_user}:#{RMT::Config.http_client.proxy_password}"
    end
  end

end
