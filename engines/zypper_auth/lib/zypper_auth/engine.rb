module ZypperAuth
  class << self
    def auth_logger
      Thread.current[:logger] ||= ::Logger.new('/var/lib/rmt/zypper_auth.log')
      Thread.current[:logger].reopen
      Thread.current[:logger]
    end

    def zypper_auth_message(request, system, verification_provider, message)
      details = [ "System login: #{system.login}", "IP: #{request.remote_ip}" ]
      details << "Instance ID: #{verification_provider.instance_id}" if verification_provider.instance_id
      details << "Billing info: #{verification_provider.instance_billing_info}" if verification_provider.instance_billing_info

      ZypperAuth.auth_logger.info <<~LOGMSG
        Access to the repos denied: #{message}
        #{details.join(', ')}
      LOGMSG
    end
  end

  class Engine < ::Rails::Engine
    isolate_namespace ZypperAuth
    config.generators.api_only = true

    config.after_initialize do
      ::V3::ServiceSerializer.class_eval do
        alias_method :original_url, :url
        def url
          original_url = original_url()
          url = URI(original_url)
          "plugin:/susecloud?credentials=#{object.name}&path=" + url.path
        end
      end

      # replaces URLs in API response JSON
      Api::Connect::V3::Systems::ActivationsController.class_eval do
        def index
          respond_with(
            @system.activations,
            each_serializer: ::V3::ActivationSerializer,
            base_url: request.base_url,
            include: '*.*'
          )
        end
      end

      # replaces URLs in API response JSON
      Api::Connect::V3::Systems::ProductsController.class_eval do
        def render_service
          status = ((request.put? || request.post?) ? 201 : 200)
          # manually setting request method, so respond_with actually renders content also for PUT
          request.instance_variable_set(:@request_method, 'GET')

          respond_with(
            @product.service,
            serializer: ::V3::ServiceSerializer,
            base_url: request.base_url,
            obsoleted_service_name: @obsoleted_service_name,
            status: status
          )
        end
      end

      RMT::Misc.class_eval do
        class << self
          alias_method :original_make_repo_url, :make_repo_url

          def make_repo_url(base_url, repo_local_path, service_name = nil)
            original_url = original_make_repo_url(base_url, repo_local_path, service_name)
            url = URI(original_url)
            "plugin:/susecloud?credentials=#{service_name}&path=" + url.path
          end
        end
      end

      ServicesController.class_eval do
        # additional validation for zypper service XML controller
        before_action :verify_instance
        def verify_instance
          unless InstanceVerification.verify_instance(request, logger, @system)
            render(xml: { error: 'Instance verification failed' }, status: 403)
          end
        end
      end

      StrictAuthentication::AuthenticationController.class_eval do
        alias_method :original_path_allowed?, :path_allowed?

        # additional validation for strict_authentication auth subrequest
        def path_allowed?(headers)
          paths_allowed = original_path_allowed?(headers)
          return false unless paths_allowed

          return true if @system.byos?

          instance_verified = InstanceVerification.verify_instance(request, logger, @system)
          DataExport.handler.new(@system, request, params, logger).export_rmt_data if DataExport.handler.presence && instance_verified

          instance_verified
        rescue StandardError => e
          logger.error('Unexpected data export error has occurred:')
          logger.error(e.message)
          logger.error("System login: #{@system.login}, IP: #{request.remote_ip}")
          false
        end
      end
    end
  end
end
