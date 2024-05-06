module Registry
  class Engine < ::Rails::Engine
    isolate_namespace Registry
    config.generators.api_only = true

    config.after_initialize do
      Api::Connect::V3::Systems::ActivationsController.class_eval do
        before_action :handle_cache, only: %w[index]

        def handle_cache
          unless request.headers['X-Instance-Data'] && ZypperAuth.verify_instance(request, logger, @system, registry: true)
            render(xml: { error: 'Instance verification failed' }, status: :forbidden)
          end
        end
      end
    end
  end
end
