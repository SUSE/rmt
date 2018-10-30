module StrictAuthentication
  class Engine < ::Rails::Engine
    isolate_namespace StrictAuthentication
    config.generators.api_only = true

    config.after_initialize do
      puts "This is where we do evil stuff!"
      puts $LOAD_PATH

      ::ServicesController.class_eval do
        before_action :authenticate_system
      end

    end
  end
end
