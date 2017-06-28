module SUSE
  module Misc
    def self.uri_replace_hostname(url, scheme, host, port)
      uri = URI.parse(url)
      uri.scheme = scheme
      uri.host = host
      uri.port = port
      uri.path = '/repo' + uri.path # FIXME: repo path from the config
      uri
    end
  end
end
