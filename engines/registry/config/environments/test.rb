# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  config.access_policies = 'engines/registry/spec/data/access_policies.yml'
  config.registry_private_key = OpenSSL::PKey::RSA.new(2048)
  config.registry_public_key = config.registry_private_key.public_key
  config.autoload_paths << Rails.root.join('engines/registry/spec/support/')
end
