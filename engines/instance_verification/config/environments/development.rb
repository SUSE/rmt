# :nocov:
module InstanceVerification
  class Application < Rails::Application
    config.cache_config_file = Rails.root.join('engines/registry/spec/data/rmt-cache-trim.sh')
    repo_cache_base_dir = 'tmp/cache/repository'
    config.repo_payg_cache_dir = Rails.root.join("#{repo_cache_base_dir}/payg")
    config.repo_byos_cache_dir = Rails.root.join("#{repo_cache_base_dir}/byos")
    config.repo_hybrid_cache_dir = Rails.root.join("#{repo_cache_base_dir}/hybrid")
    config.registry_cache_dir = Rails.root.join('tmp/cache/registry')
  end
end
# :nocov:
