module StrictAuthentication
  class Engine < ::Rails::Engine
    isolate_namespace StrictAuthentication
    config.generators.api_only = true

    config.generators do |g|
      g.test_framework :rspec
    end

    config.after_initialize do
      ::ServicesController.class_eval do
        include StrictAuthentication

        prepend_before_action :verify_service_access, only: %w[show]
        prepend_before_action :authenticate_system

        def verify_service_access
          @system.services.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render plain: 'Product is not registered', status: :forbidden
        end
      end
    end
  end
end
