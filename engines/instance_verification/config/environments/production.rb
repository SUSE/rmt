# :nocov:
module InstanceVerification
  class Application < Rails::Application
    config.cache_config_file = '/var/lib/rmt/rmt-cache-trim.sh'
    config.repo_cache_dir = Rails.root.join('tmp/cache/repository')
    config.registry_cache_dir = Rails.root.join('tmp/cache/registry')
    cache_config_content = [
      "REPOSITORY_CLIENT_CACHE_DIRECTORY=#{config.repo_cache_dir}",
      'REPOSITORY_CACHE_EXPIRY_MINUTES=20',
      "REGISTRY_CLIENT_CACHE_DIRECTORY=#{config.registry_cache_dir}",
      "REGISTRY_CACHE_EXPIRY_MINUTES=#{Settings[:registry].try(:token_expiration) || 480}" # 480: 8 hours in minutes
    ].join("\n")
    File.write(config.cache_config_file, cache_config_content)
  end
end
# :nocov:
