require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_record/railtie'

require 'action_controller/railtie'
require 'action_view/railtie'
# require 'action_mailer/railtie'
# require 'active_job/railtie'
# require 'action_cable/engine'
# require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

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
    config.load_defaults 5.1

    config.autoload_paths << Rails.root.join('lib')
    config.autoload_paths << Rails.root.join('app/validators')

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.generators do |g|
      g.test_framework :rspec
    end

  end
end
