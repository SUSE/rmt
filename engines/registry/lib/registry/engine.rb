module Registry
  class Engine < ::Rails::Engine
    isolate_namespace Registry
    config.generators.api_only = true

    config.after_initialize do
      Api::Connect::V3::Systems::ActivationsController.class_eval do
        before_action :handle_auth_cache, only: %w[index]

        def handle_auth_cache
          unless InstanceVerification.verify_instance(request, logger, @system)
            render(xml: { error: 'Instance verification failed' }, status: :forbidden)
          end
        end
      end

      Api::Connect::V3::Systems::SystemsController.class_eval do
        before_action :remove_auth_cache, only: %w[deregister]

        def remove_auth_cache
          InstanceVerification.remove_registry_cache(request.remote_ip, @system.login)
        end
      end
    end
  end
end
