# :nocov:
module InstanceVerification
  class Application < Rails::Application
    config.cache_config_file = Rails.root.join('engines/registry/spec/data/rmt-cache-trim.sh')
    config.repo_cache_dir = 'repo/cache'
    config.registry_cache_dir = 'registry/cache'
  end
end
# :nocov:
