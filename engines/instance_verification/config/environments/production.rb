# :nocov:
module InstanceVerification
  class Application < Rails::Application
    config.cache_config_file = '/var/lib/rmt/rmt-cache-trim.sh'
    config.repo_cache_dir = '/run/rmt/cache/repository'
    cache_config_content = [
      "REPOSITORY_CLIENT_CACHE_DIRECTORY=#{config.repo_cache_dir}",
      'REPOSITORY_CACHE_EXPIRY_MINUTES=20'
    ].join("\n")
    File.write(config.cache_config_file, cache_config_content)
  end
end
# :nocov:
