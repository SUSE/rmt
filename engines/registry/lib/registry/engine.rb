module Registry
  # rubocop:disable Lint/EmptyClass
  class << self
  end
  # rubocop:enable Lint/EmptyClass

  class Engine < ::Rails::Engine
    isolate_namespace Registry
    config.generators.api_only = true

    config.after_initialize do
      Api::Connect::V3::Systems::ActivationsController.class_eval do
        # only run instance verification if the instance metadata is present
        # and  run the cache refresh if instance metadata gets verified
        before_action :refresh_auth_cache, only: %w[index], if: -> { request.headers['X-Instance-Data'] }

        def refresh_auth_cache
          unless InstanceVerification.verify_instance(request, logger, @system)
            render(xml: { error: 'Instance verification failed' }, status: :forbidden)
          end
        end
      end

      Api::Connect::V3::Systems::SystemsController.class_eval do
        before_action :remove_auth_cache, only: %w[deregister]

        def remove_auth_cache
          registry_cache_key = InstanceVerification.build_cache_entry(request.remote_ip, @system.login, {}, 'registry', nil)
          InstanceVerification.remove_entry_from_cache(registry_cache_key, 'registry')
        end
      end
    end
  end
end
