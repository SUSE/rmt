# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  config.cache_config_file = Rails.root.join('engines/registry/spec/data/rmt-cache-trim.sh')
  config.repo_payg_cache_dir = 'repo/payg/cache'
  config.repo_byos_cache_dir = 'repo/byos/cache'
  config.repo_hybrid_cache_dir = 'repo/hybrid/cache'
  config.registry_cache_dir = 'registry/cache'
  config.expire_repo_payg_cache = 20
  config.expire_repo_byos_cache = 1440 # 24h in minutes
  config.expire_repo_hybrid_cache = 1440 # 24h in minutes
  config.expire_registry_cache = 840 # 8h in minutes
end
