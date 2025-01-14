module ZypperAuth
  class << self
    def auth_logger
      Thread.current[:logger] ||= ::Logger.new('/var/lib/rmt/zypper_auth.log')
      Thread.current[:logger].reopen
      Thread.current[:logger]
    end

    def verify_instance(request, logger, system, params_product_id = nil)
      return false unless request.headers['X-Instance-Data']

      base_product = system.products.find_by(product_type: 'base')
      return false unless base_product

      # check the cache for the system (20 min)
      cache_key = [request.remote_ip, system.login, base_product.id].join('-')
      cache_path = File.join(Rails.application.config.repo_cache_dir, cache_key)
      if File.exist?(cache_path)
        # only update registry cache key
        InstanceVerification.update_cache(request.remote_ip, system.login, nil, registry: true)
        return true
      end

      verification_provider = InstanceVerification.provider.new(
        logger,
        request,
        base_product.attributes.symbolize_keys.slice(:identifier, :version, :arch, :release_type),
        Base64.decode64(request.headers['X-Instance-Data'].to_s) # instance data
      )

      is_valid = verification_provider.instance_valid?
      return false if is_valid && system.hybrid? && !has_active_subscription?(request, system, verification_provider, params_product_id)

      # update repository and registry cache
      InstanceVerification.update_cache(request.remote_ip, system.login, base_product.id)
      is_valid
    rescue InstanceVerification::Exception => e
      return has_active_subscription?(request, system, verification_provider, params_product_id) if system.byos?

      ZypperAuth.zypper_auth_message(request, system, verification_provider, e.message)
      false
    rescue StandardError => e
      logger.error('Unexpected instance verification error has occurred:')
      logger.error(e.message)
      logger.error("System login: #{system.login}, IP: #{request.remote_ip}")
      logger.error('Backtrace:')
      logger.error(e.backtrace)
      false
    end

    def has_active_subscription?(request, system, verification_provider, params_product_id = nil)
      if params_product_id.present?
        product_class = Product.find_by(id: params_product_id).product_class
        result = SccProxy.scc_check_subscription_expiration(request.headers, system, product_class)
      else
        # no product id provided
        # check all non free extensions subscriptions with SCC, if any
        paid_extensions = system.products.select { |prod| prod if !prod.free && prod.product_type == 'extension' }
        return true if paid_extensions.empty? && system.hybrid?

        all_active = paid_extensions.all? do |paid_extension|
          result = SccProxy.scc_check_subscription_expiration(request.headers, system, paid_extension.product_class)
          result[:is_active]
        end
        return true if all_active

        # check BYOS on SCC
        result = SccProxy.scc_check_subscription_expiration(request.headers, system) if system.byos?
      end
      return true if result[:is_active]

      ZypperAuth.zypper_auth_message(request, system, verification_provider, result[:message])
      false
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
          unless ZypperAuth.verify_instance(request, logger, @system, params.fetch('id', nil))
            render(xml: { error: 'Instance verification failed' }, status: 403)
          end
        end
      end

      StrictAuthentication::AuthenticationController.class_eval do
        alias_method :original_path_allowed?, :path_allowed?

        # additional validation for strict_authentication auth subrequest
        def path_allowed?(headers)
          return false unless original_path_allowed?(headers)

          if @system.hybrid? || @system.byos?
            paid_extensions = @system.products.select { |prod| prod if !prod.free && prod.product_type == 'extension' }
            paid_extensions.each do |paid_extension|
              repos_paths = paid_extension.repositories.pluck(:local_path)
              repos_paths.each do |repo_path|
                if headers.fetch('X-Original-URI', '').include? repo_path
                  logger.info "verifying paid extension #{paid_extension.identifier}"
                  return ZypperAuth.verify_instance(request, logger, @system, paid_extension.id)
                end
              end
            end
          end
          # either no hybrid system, no need to check for paid extensions
          # or path not found on paid extensions and system is hybrid
          ZypperAuth.verify_instance(request, logger, @system)
        end
      end
    end
  end
end
