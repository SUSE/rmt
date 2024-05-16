# :nocov:
module Registry
  class Application < Rails::Application
    # registry config needed
    config.autoloader = :classic
    config.registry_private_key = OpenSSL::PKey::RSA.new(
      File.read('/etc/rmt/ssl/internal-registry.key')
      )
    config.registry_public_key = config.registry_private_key.public_key
    config.access_policies = '/etc/rmt/access_policies.yml'
  end
end
# :nocov:
