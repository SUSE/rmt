require 'typhoeus'
require 'rmt/config'

class RMT::HttpRequest < Typhoeus::Request

  def set_defaults
    Typhoeus::Config.user_agent = "RMT/#{RMT::VERSION}"
    Typhoeus::Config.verbose = Settings.http_client.verbose || nil

    super

    options[:proxy] = Settings.http_client.proxy
    options[:proxyauth] = Settings.http_client.proxy_auth ? Settings.http_client.proxy_auth.to_sym : :any

    if (Settings.http_client.proxy_user && Settings.http_client.proxy_password)
      options[:proxyuserpwd] = "#{Settings.http_client.proxy_user}:#{Settings.http_client.proxy_password}"
    end
  end

end
