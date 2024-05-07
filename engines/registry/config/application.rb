require 'rails'

module Registry
  class Application < Rails::Application
    # :nocov:
    if Rails.env.production?
      # registry config needed
      config.autoloader = :classic
      config.registry_private_key = OpenSSL::PKey::RSA.new(File.read('/etc/rmt/ssl/rmt-server.key'))
      config.registry_public_key = config.registry_private_key.public_key
      config.access_policies = '/etc/rmt/access_policies.yml'
      config.regisry_cache_dir = '/run/rmt/cache/registry'
      # registry config needed end
    end
    # :nocov:
  end
end
