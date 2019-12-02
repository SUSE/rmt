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

    # Abort download if speed is below 512 bytes/sec for 120 sec, to prevent downloads from getting stuck
    options[:low_speed_limit] = Settings.try(:http_client).try(:low_speed_limit) ? Settings.try(:http_client).try(:low_speed_limit) : 512
    options[:low_speed_time] = Settings.try(:http_client).try(:low_speed_time) ? Settings.try(:http_client).try(:low_speed_time) : 120
    options[:accept_encoding] = 'gzip'
  end

end
