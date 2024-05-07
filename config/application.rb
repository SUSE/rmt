require_relative 'boot'

require 'rails'

# Pick the frameworks you want:
require 'active_model/railtie'
# require "active_job/railtie"
require 'active_record/railtie'
# require "active_storage/engine"
require 'action_controller/railtie'
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require 'action_view/railtie'
# require "action_cable/engine"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)


# Engine loading mechanism
# :nocov:
if (Rails.env.production? || ENV['RMT_LOAD_ENGINES'])
  Dir.glob("#{__dir__}/../engines/*").select { |i| File.directory?(i) }.each do |dir|
    engine_name = File.basename(dir)
    filename = File.expand_path(File.join(dir, 'lib', "#{engine_name}.rb"))
    require_relative(filename) if File.exist?(filename)
  end
end
# :nocov:

module RMT
  class CustomConfiguration < Rails::Application::Configuration

    def database_configuration
      require 'rmt/config'
      key_name = Rails.env.production? ? 'database' : "database_#{Rails.env}"

      { Rails.env => RMT::Config.db_config(key_name) }
    end

  end

  Rails::Application.class_eval do
    def config
      @config ||= RMT::CustomConfiguration.new(self.class.find_root(self.class.called_from))
    end
  end

  class Application < Rails::Application

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.eager_load_paths << Rails.root.join('lib')
    config.eager_load_paths << Rails.root.join('app', 'validators')

    config.cache_config_file = '/var/lib/rmt/rmt-cache-trim.sh'
    config.repo_cache_dir = '/run/rmt/cache/repository'
    cache_config_content = %(REPOSITORY_CLIENT_CACHE_DIRECTORY=#{config.repo_cache_dir}
REPOSITORY_CACHE_EXPIRY_MINUTES=20
)
    File.write(config.cache_config_file, cache_config_content)
    # :nocov:
    if defined?(Registry::Engine) && Rails.env.production?
      # registry config needed
      config.autoloader = :classic
      config.registry_private_key = OpenSSL::PKey::RSA.new(
        File.read('/etc/rmt/ssl/rmt-server.key')
        )
      config.registry_public_key = config.registry_private_key.public_key
      config.access_policies = '/etc/rmt/access_policies.yml'

      # registry config needed end
    end
    # :nocov:

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.generators do |g|
      g.test_framework :rspec
    end

    # Rails initialization process requires a secret key base present in either:
    # - SECRET_KEY_BASE env
    # - credentials.secret_key_base
    # - secrets.secret_key_base
    #
    # Else the boot process will be halted. RMT does not use any of those
    # facilities. Hardcoding it here keeps rails happy and allows the boot
    # process to continue.
    config.require_master_key = false
    config.read_encrypted_secrets = false
    config.secret_key_base = 'rmt-does-not-use-this'
  end
end
