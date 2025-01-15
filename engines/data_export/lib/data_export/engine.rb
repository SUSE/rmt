module DataExport
  class Engine < ::Rails::Engine
    isolate_namespace DataExport
    config.after_initialize do
      # replaces RMT registration for SCC registration
      Api::Connect::V3::Subscriptions::SystemsController.class_eval do
        after_action :update_info, only: %i[announce_system], if: -> { response.successful? }

        def update_info
          # no need to check if system is nil
          # as the response is successful
          return if @system.byos?

          data_export_handler = DataExport.handler.new(
            @system,
            request,
            params,
            logger
          )
          data_export_handler.update_info
          logger.info "System #{@system.login} info updated by data warehouse handler after announcing the system"
        rescue StandardError => e
          logger.error('Unexpected data export error has occurred:')
          logger.error(e.message)
          logger.error("System login: #{@system.login}, IP: #{request.remote_ip}")
          logger.error('Backtrace:')
          logger.error(e.backtrace)
        end
      end

      Api::Connect::V3::Systems::SystemsController.class_eval do
        after_action :update_info, only: %i[update], if: -> { response.successful? }

        def update_info
          data_export_handler = DataExport.handler.new(
            @system,
            request,
            params,
            logger
          )
          data_export_handler.update_info
          logger.info "System #{@system.login} info updated by data warehouse handler after updating the system"
        rescue StandardError => e
          logger.error('Unexpected data warehouse error has occurred:')
          logger.error(e.message)
          logger.error("System login: #{@system.login}, IP: #{request.remote_ip}")
          logger.error('Backtrace:')
          logger.error(e.backtrace)
        end
      end
    end
  end
end
