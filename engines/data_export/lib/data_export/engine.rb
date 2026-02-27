module DataExport
  class Engine < ::Rails::Engine
    isolate_namespace DataExport
    config.after_initialize do
      Api::Connect::V3::Systems::SystemsController.class_eval do
        # if the difference between registered_at and last_seen_at
        # is shorter than 10 seconds, it is a registration
        after_action :export_rmt_data, only: %i[update], if: lambda {
          DataExport.handler.presence && response.successful? && !@system.byos? &&
          @system.products.present? && (@system.last_seen_at - @system.registered_at) > 10.seconds
        }

        def export_rmt_data
          @system.activations.each do |activation|
            params[:dw_product_name] = activation.service.product.product_string
            send_data
          end
        rescue StandardError => e
          logger.error('Unexpected data export error has occurred:')
          logger.error(e.message)
          logger.error("System login: #{@system.login}, IP: #{request.remote_ip}")
          logger.error('Backtrace:')
          logger.error(e.backtrace)
        end

        protected

        def send_data
          data_export_handler = DataExport.handler.new(
            @system,
            request,
            params,
            logger
          )
          data_export_handler.export_rmt_data
          logger.info "System #{@system.login} info with #{params} params updated by data export handler after updating the system"
        end
      end

      Api::Connect::V3::Systems::ProductsController.class_eval do
        after_action :export_rmt_data, only: %i[activate upgrade], if: -> { DataExport.handler.presence && response.successful? && !@system.byos? }

        def export_rmt_data
          params[:dw_product_name] = @product.name
          data_export_handler = DataExport.handler.new(
            @system,
            request,
            params,
            logger
          )
          data_export_handler.export_rmt_data
          logger.info "System #{@system.login} info updated by data export handler after activating or updating the product #{@product.product_string}"
        rescue StandardError => e
          logger.error('Unexpected data export error has occurred:')
          logger.error(e.message)
          logger.error("System login: #{@system.login}, IP: #{request.remote_ip}")
          logger.error('Backtrace:')
          logger.error(e.backtrace)
        end
      end
    end
  end
end
