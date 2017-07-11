module SUSE
  module Misc
    def self.uri_replace_hostname(url, new_url)
      uri = URI.parse(url)
      new_uri = URI.parse(new_url)
      uri.scheme = new_uri.scheme
      uri.host = new_uri.host
      uri.port = new_uri.port
      uri.path = '/repo' + uri.path # FIXME: repo path from the config
      uri
    end
  end
end
