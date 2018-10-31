module StrictAuthentication
  class Engine < ::Rails::Engine
    isolate_namespace StrictAuthentication
    config.generators.api_only = true

    config.generators do |g|
      g.test_framework :rspec
    end

    config.after_initialize do
      ::ServicesController.class_eval do
        before_action :authenticate_system
      end
    end
  end
end
