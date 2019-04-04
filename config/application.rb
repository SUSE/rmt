require_relative 'boot'

require 'rails'

require 'active_model/railtie'
require 'active_record/railtie'

require 'action_controller/railtie'
require 'action_view/railtie'

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
    config.load_defaults 5.1

    config.autoload_paths << Rails.root.join('lib')
    config.autoload_paths << Rails.root.join('app', 'validators')

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
