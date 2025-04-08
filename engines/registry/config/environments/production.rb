# :nocov:
module Registry
  class Application < Rails::Application
    # registry config needed
    PRIVATE_KEY_PATH = '/etc/rmt/ssl/internal-registry.key'.freeze
    ACCESS_POLICIES_PATH = '/etc/rmt/access_policies.yml'.freeze
    config.autoloader = :classic
    config.registry_private_key = ''
    config.registry_public_key = ''
    if File.exist?(PRIVATE_KEY_PATH)
      # set registry key only if private key exists
      # because registry is optional
      config.registry_private_key = OpenSSL::PKey::RSA.new(
        File.read(PRIVATE_KEY_PATH)
      )
      config.registry_public_key = config.registry_private_key.public_key
    end
    config.access_policies = ACCESS_POLICIES_PATH
  end
end
# :nocov:
