require 'rmt/config'

module RMT
  module Misc
    def self.make_repo_url(base_url, local_path)
      URI.join(base_url, File.join(Settings.mirroring.mirror_url_prefix, local_path)).to_s
    end
  end
end
