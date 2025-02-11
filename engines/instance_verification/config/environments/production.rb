# :nocov:
module InstanceVerification
  class Application < Rails::Application
    config.cache_config_file = '/var/lib/rmt/rmt-cache-trim.sh'
    repo_cache_base_dir = 'tmp/cache/repository'
    config.repo_payg_cache_dir = Rails.root.join("#{repo_cache_base_dir}/payg")
    config.repo_byos_cache_dir = Rails.root.join("#{repo_cache_base_dir}/byos")
    config.repo_hybrid_cache_dir = Rails.root.join("#{repo_cache_base_dir}/hybrid")
    config.registry_cache_dir = Rails.root.join('tmp/cache/registry')
    config.expire_repo_payg_cache = 20
    config.expire_repo_byos_cache = 1440 # 24h in minutes
    config.expire_repo_hybrid_cache = 1440 # 24h in minutes
    config.expire_registry_cache = 840 # 8h in minutes
    cache_config_content = [
      "REPOSITORY_CLIENT_PAYG_CACHE_DIRECTORY=#{config.repo_payg_cache_dir}",
      "REPOSITORY_PAYG_CACHE_EXPIRY_MINUTES=#{config.expire_repo_payg_cache}",
      "REPOSITORY_CLIENT_BYOS_CACHE_DIRECTORY=#{config.repo_byos_cache_dir}",
      "REPOSITORY_BYOS_CACHE_EXPIRY_MINUTES=#{config.expire_repo_byos_cache}",
      "REPOSITORY_CLIENT_HYBRID_CACHE_DIRECTORY=#{config.repo_hybrid_cache_dir}",
      "REPOSITORY_HYBRID_CACHE_EXPIRY_MINUTES=#{config.expire_repo_hybrid_cache}",
      "REGISTRY_CLIENT_CACHE_DIRECTORY=#{config.registry_cache_dir}",
      "REGISTRY_CACHE_EXPIRY_MINUTES=#{Settings[:registry].try(:token_expiration) || config.expire_registry_cache}" # 480: 8 hours in minutes
    ].join("\n")
    File.write(config.cache_config_file, cache_config_content)
  end
end
# :nocov:
