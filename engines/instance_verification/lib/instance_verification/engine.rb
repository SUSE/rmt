module InstanceVerification
  class Engine < ::Rails::Engine
    isolate_namespace InstanceVerification
    config.generators.api_only = true

    config.after_initialize do
      Api::Connect::V3::Subscriptions::SystemsController.class_eval do
        after_action :save_instance_data, only: %i[announce_system]

        # store IID for later product activation checks
        def save_instance_data
          return true unless (@system && params[:instance_data])
          @system.hw_info.instance_data = params[:instance_data]
          @system.hw_info.save!
        end
      end

      Api::Connect::V3::Systems::ProductsController.class_eval do
        before_action :verify_base_product_activation, only: %i[activate]
        before_action :verify_base_product_upgrade, only: %i[upgrade]

        def verify_base_product_activation
          is_valid = InstanceVerification.provider.instance_valid?(
            request,
            params.permit(:identifier, :version, :arch, :release_type).to_h,
            @system.hw_info&.instance_data
          )

          raise ActionController::TranslatedError.new('Instance verification failed') unless is_valid
        end

        def verify_base_product_upgrade
          # TODO: verify that the base product doesn't change in the migration
          raise ActionController::TranslatedError.new('Migration not allowed on this instance type')
        end
      end
    end
  end
end
