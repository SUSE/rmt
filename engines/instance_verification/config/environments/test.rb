# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  config.cache_config_file = Rails.root.join('engines/registry/spec/data/rmt-cache-trim.sh')
  config.repo_cache_dir = 'repo/cache'
  config.registry_cache_dir = 'registry/cache'
end
