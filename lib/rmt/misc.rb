require 'rmt/config'

module RMT
  module Misc
    def self.make_repo_url(base_url, local_path)
      URI.join(base_url, File.join(Settings.mirroring.mirror_url_prefix, local_path)).to_s
    end

    def self.replace_uri_parts(uri, replacement)
      uri = URI(uri)
      replacement_uri = URI(replacement)

      uri.scheme = replacement_uri.scheme
      uri.host = replacement_uri.host
      uri.port = replacement_uri.port
      uri.path = File.join(replacement_uri.path, uri.path)
      uri.to_s
    end
  end
end
