require 'rmt/config'

module RMT
  module Misc
    def self.make_repo_url(base_url, local_path, service_name = nil)
      uri = URI.join(base_url, File.join(RMT::DEFAULT_MIRROR_URL_PREFIX, local_path))
      uri.query = "credentials=#{service_name}" if service_name
      uri.to_s
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

    def self.make_smt_service_name(url)
      # SMT service was always accessed via plain HTTP
      url = URI(url)
      url.scheme = 'http'

      "SMT-#{url}".gsub!(%r{:*/+}, '_').tr('.', '_').gsub(/_$/, '')
    end
  end
end
