module DataExport
  class Engine < ::Rails::Engine
    isolate_namespace DataExport
    config.after_initialize do
      # replaces RMT registration for SCC registration
      Api::Connect::V3::Subscriptions::SystemsController.class_eval do
        after_action :export_rmt_data, only: %i[announce_system], if: -> { response.successful? && !@system.byos? }

        def export_rmt_data
          # no need to check if system is nil
          # as the response is successful
          data_export_handler = DataExport.handler.new(
            @system,
            request,
            params,
            logger
          )
          data_export_handler.export_rmt_data
          logger.info "System #{@system.login} info updated by data export handler after announcing the system"
        rescue StandardError => e
          logger.error('Unexpected data export error has occurred:')
          logger.error(e.message)
          logger.error("System login: #{@system.login}, IP: #{request.remote_ip}")
          logger.error('Backtrace:')
          logger.error(e.backtrace)
        end
      end

      Api::Connect::V3::Systems::SystemsController.class_eval do
        after_action :export_rmt_data, only: %i[update], if: -> { response.successful? && !@system.byos? }

        def export_rmt_data
          if @system.products.empty?
            send_data
          else
            @system.products.pluck(:name).each do |prod_name|
              params[:dw_product_name] = prod_name
              send_data
            end
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
        after_action :export_rmt_data, only: %i[activate upgrade], if: -> { response.successful? && !@system.byos? }

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
