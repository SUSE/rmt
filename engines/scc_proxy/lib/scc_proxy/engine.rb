require 'json'
require 'net/http'

ANNOUNCE_URL = 'https://scc.suse.com/connect/subscriptions/systems'.freeze
SYSTEM_PRODUCTS_URL = 'https://scc.suse.com/connect/systems/products'.freeze
SYSTEMS_ACTIVATIONS_URL = 'https://scc.suse.com/connect/systems/activations'.freeze
DEREGISTER_SYSTEM_URL = 'https://scc.suse.com/connect/systems'.freeze
DEREGISTER_PRODUCT_URL = 'https://scc.suse.com/connect/systems/products'.freeze
NET_HTTP_ERRORS = [
  Errno::EINVAL,
  Errno::ECONNRESET,
  EOFError,
  Net::HTTPBadResponse,
  Net::HTTPForbidden,
  Net::HTTPGone,
  Net::HTTPBadRequest,
  Net::HTTPFound,
  Net::HTTPHeaderSyntaxError,
  Net::ProtocolError,
  Net::OpenTimeout,
  Net::HTTPServerException,
  Net::HTTPFatalError,
  OpenSSL::SSL::SSLError,
  Errno::EHOSTUNREACH,
  Net::HTTPRetriableError
].freeze

INSTANCE_ID_KEYS = {
  amazon: 'instanceId',
  google: 'instance_id',
  microsoft: 'vmId'
}.freeze

# rubocop:disable Metrics/ModuleLength
module SccProxy
  class << self

    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_accessor :instance_id

    # rubocop:enable ThreadSafety/ClassAndModuleAttributes

    # rubocop:disable ThreadSafety/InstanceVariableInClassMethod
    def headers(auth, params)
      @instance_id = if params && params.class != String
                       get_instance_id(params)
                     else
                       # if it is not JSON, it is the system_token already
                       # announce system has metadata
                       # activate product does not have metadata
                       # so instance id comes as string
                       params
                     end

      {
        'accept' => 'application/json,application/vnd.scc.suse.com.v4+json',
        'Content-Type' => 'application/json',
        'Authorization' => auth,
        ApplicationController::SYSTEM_TOKEN_HEADER => @instance_id
      }
    end
    # rubocop:enable ThreadSafety/InstanceVariableInClassMethod

    def get_instance_id(params)
      verification_provider = InstanceVerification.provider.new(
        nil,
        nil,
        nil,
        params['instance_data']
      )
      instance_id_key = INSTANCE_ID_KEYS[params['hwinfo']['cloud_provider'].downcase.to_sym]
      iid = verification_provider.parse_instance_data
      iid[instance_id_key]
    end

    def prepare_scc_announce_request(uri_path, auth, params)
      scc_request = Net::HTTP::Post.new(uri_path, headers(auth, params))

      # Do not filter hardware information here but redirect the whole payload
      # to SCC.
      # SCC will make sure to handle the data correctly. This removes the need
      # to adapt here if information send by the client changes.
      scc_req_body = {
        hostname: params['hostname'],
        hwinfo: params['hwinfo'],
        byos_mode: params['proxy_byos_mode']
      }
      # when system is payg, we do not know whether it's hybrid or not
      # we send the login and password information to skip the validation
      # on the SCC side, that info is enough to validate the product later on
      # if the system is, in fact, hybrid
      # When activating a BYOS extension on top of a PAYG system ('hybrid mode'),
      # the system already has credentials in RMT, but is not known to SCC.
      # We announce it to SCC including its credentials in this case.
      if params['proxy_byos_mode'] == 'hybrid'
        scc_req_body[:login] = params['scc_login']
        scc_req_body[:password] = params['scc_password']
      end
      scc_request.body = scc_req_body.to_json
      scc_request
    end

    def prepare_scc_request(uri_path, product, auth, params, mode)
      params_header = params
      params_header = nil if mode == 'byos'

      scc_request = Net::HTTP::Post.new(uri_path, headers(auth, params_header))
      scc_request.body = {
        token: params[:token] || nil,
        identifier: product.identifier,
        version: product.version,
        arch: product.arch,
        release_type: product.release_type,
        email: params[:email] || nil,
        byos_mode: mode
      }.to_json
      scc_request
    end

    def prepare_scc_upgrade_request(uri_path, product, auth, mode)
      scc_request = Net::HTTP::Put.new(uri_path, headers(auth, nil))
      scc_request.body = {
        identifier: product.identifier,
        version: product.version,
        arch: product.arch,
        byos_mode: mode
      }.to_json
      scc_request
    end

    def announce_system_scc(auth, params)
      uri = URI.parse(ANNOUNCE_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_announce_request(uri.path, auth, params)
      response = http.request(scc_request)
      response.error! unless response.code_type == Net::HTTPCreated

      JSON.parse(response.body)
    end

    def scc_activate_product(system, product, auth, params, mode)
      uri = URI.parse(SYSTEM_PRODUCTS_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_request(uri.path, product, auth, params, mode)
      response = http.request(scc_request)
      unless response.code_type == Net::HTTPCreated
        error = JSON.parse(response.body)
        Rails.logger.info "Could not activate #{product.product_string}, error: #{error['error']} #{response.code}"
        error['error'] = SccProxy.parse_error(error['error']) if error['error'].include? 'json'
        # if trying to activate first product on a hybrid system
        # it means the system was "just" announced on this call
        # if product activation failed, system should get de-register from SCC
        SccProxy.deregister_system_scc(auth, system) if system.payg?

        raise ActionController::TranslatedError.new(error['error'])
      end
    end

    def deactivate_product_scc(auth, product, params, logger)
      uri = URI.parse(DEREGISTER_PRODUCT_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = Net::HTTP::Delete.new(uri.path, headers(auth, params))
      scc_request.body = {
        identifier: product.identifier,
        version: product.version,
        arch: product.arch,
        byos: true
      }.to_json
      response = http.request(scc_request)
      unless response.code_type == Net::HTTPOK
        error = JSON.parse(response.body)
        error['error'] = SccProxy.parse_error(error['error'], params[:token], params[:email]) if error['error'].include? 'json'
        logger.info "Could not de-activate product '#{product.friendly_name}', error: #{error['error']} #{response.code}"
        raise ActionController::TranslatedError.new(error['error'])
      end
      response
    end

    def deregister_system_scc(auth, system)
      uri = URI.parse(DEREGISTER_SYSTEM_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = Net::HTTP::Delete.new(uri.path, headers(auth, system.system_token))
      response = http.request(scc_request)
      unless response.code_type == Net::HTTPNoContent
        error = JSON.parse(response.body)
        Rails.logger.info "Could not de-activate system #{system.login}, error: #{error['error']} #{response.code}"
        error['error'] = SccProxy.parse_error(error['error'], params[:token], params[:email]) if error['error'].include? 'json'
        raise ActionController::TranslatedError.new(error['error'])
      end
      Rails.logger.info 'System successfully deregistered from SCC'
    end

    def parse_error(error_message, token = nil, email = nil)
      error_message = error_message[0..(error_message.index('json') - 1)].strip
      error_message = error_message.gsub(token, '').squish if token
      error_message = error_message.gsub(email, '').strip if email
      error_message
    end

    def get_scc_activations(headers, system_token, mode, login)
      auth = headers['HTTP_AUTHORIZATION'] if headers && headers.include?('HTTP_AUTHORIZATION')
      uri = URI.parse(SYSTEMS_ACTIVATIONS_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      uri.query = URI.encode_www_form({ byos_mode: mode })
      scc_request = Net::HTTP::Get.new(uri.path, headers(auth, system_token))
      response = http.request(scc_request)
      unless response.code_type == Net::HTTPOK
        Rails.logger.info "Could not get the system (#{login}) activations, error: #{response.message} #{response.code}"
        raise ActionController::TranslatedError.new(response.body)
      end
      JSON.parse(response.body)
    end

    def product_path_access(x_original_uri, products_ids)
      products = Product.where(id: products_ids)
      product_paths = products.map { |prod| prod.repositories.pluck(:local_path) }.flatten
      product_paths.any? { |path| x_original_uri.include?(path) }
    end

    def product_class_access(scc_systems_activations, product)
      active_products_names = scc_systems_activations.map { |act| act['service']['product']['product_class'] if act['status'].casecmp('active').zero? }.flatten
      if active_products_names.include?(product)
        { is_active: true }
      else
        expired_products_names = scc_systems_activations.map do |act|
          act['service']['product']['product_class'] unless act['status'].casecmp('active').zero?
        end.flatten
        message = if expired_products_names.all?(&:nil?)
                    'Product not activated.'
                  elsif expired_products_names.include?(product)
                    'Subscription expired.'
                  else
                    'Unexpected error when checking product subscription.'
                  end
        { is_active: false, message: message }
      end
    end

    def activations_fail_state(scc_systems_activations, headers, product = nil)
      return SccProxy.product_class_access(scc_systems_activations, product) unless product.nil?

      active_products_ids = scc_systems_activations.map { |act| act['service']['product']['id'] if act['status'].casecmp('active').zero? }.flatten
      x_original_uri = headers.fetch('X-Original-URI', '')
      if SccProxy.product_path_access(x_original_uri, active_products_ids)
        { is_active: true }
      else
        # product not found in the active subscriptions, check the expired ones
        expired_products_ids = scc_systems_activations.map { |act| act['service']['product']['id'] unless act['status'].casecmp('active').zero? }.flatten
        if expired_products_ids.all?(&:nil?)
          {
            is_active: false,
            message: 'Product not activated.'
          }
        end
        if SccProxy.product_path_access(x_original_uri, expired_products_ids)
          {
            is_active: false,
            message: 'Subscription expired.'
          }
        else
          {
            is_active: false,
            message: 'Unexpected error when checking product subscription.'
          }
        end
      end
    end

    def scc_check_subscription_expiration(headers, login, system_token, mode, product = nil)
      scc_systems_activations = SccProxy.get_scc_activations(
        headers, system_token, mode, login
        )
      return { is_active: false, message: 'No activations.' } if scc_systems_activations.empty?

      no_status_products_ids = scc_systems_activations.map do |act|
        act['service']['product']['id'] if (act['status'].nil? && act['expires_at'].nil?)
      end.flatten.compact
      return { is_active: true } unless no_status_products_ids.all?(&:nil?)

      SccProxy.activations_fail_state(scc_systems_activations, headers, product)
    rescue StandardError
      { is_active: false, message: 'Could not check the activations from SCC' }
    end

    def scc_upgrade(auth, product, system_login, mode, logger)
      uri = URI.parse(SYSTEM_PRODUCTS_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_upgrade_request(uri.path, product, auth, mode)
      response = http.request(scc_request)
      unless response.code_type == Net::HTTPCreated
        logger.info "Could not upgrade the system (#{system_login}), error: #{response.message} #{response.code}"
        response.message = SccProxy.parse_error(response.message) if response.message.include? 'json'
        raise ActionController::TranslatedError.new(response.body)
      end
      response
    end
  end

  # rubocop:disable Metrics/ClassLength
  class Engine < ::Rails::Engine
    isolate_namespace SccProxy
    config.generators.api_only = true

    config.after_initialize do
      # replaces RMT registration for SCC registration
      Api::Connect::V3::Subscriptions::SystemsController.class_eval do
        def announce_system
          auth_header = nil
          auth_header = request.headers['HTTP_AUTHORIZATION'] if request.headers.include?('HTTP_AUTHORIZATION')
          system_information = hwinfo_params[:hwinfo].to_json
          instance_data = params.fetch(:instance_data, nil)
          if has_no_regcode?(auth_header)
            # no token sent to check with SCC
            # standard announce case
            @system = System.create!(
              hostname: params[:hostname],
              system_information: system_information,
              proxy_byos_mode: :payg,
              instance_data: instance_data
            )
          else
            request.request_parameters['proxy_byos_mode'] = 'byos'
            response = SccProxy.announce_system_scc(auth_header, request.request_parameters)
            @system = System.create!(
              system_token: SccProxy.instance_id,
              login: response['login'],
              password: response['password'],
              hostname: params[:hostname],
              proxy_byos_mode: :byos,
              proxy_byos: true,
              system_information: system_information,
              instance_data: instance_data
            )
          end
          logger.info("System '#{@system.hostname}' announced")
          respond_with(@system, serializer: ::V3::SystemSerializer, location: nil)
        rescue *NET_HTTP_ERRORS => e
          logger.error(
            "Could not register system with regcode #{auth_header} " \
              "to SCC: #{e.message}"
          )
          render json: { type: 'error', error: e.message }, status: status_code(e.message), location: nil
        end

        protected

        def status_code(error_message)
          error_message[0..(error_message.index(' ') - 1)].to_i
        end

        def has_no_regcode?(auth_header)
          auth_header ||= '='
          auth_header = auth_header[(auth_header.index('=') + 1)..-1]
          auth_header.empty?
        end
      end

      Api::Connect::V3::Systems::ProductsController.class_eval do
        before_action :scc_activate_product, only: %i[activate]
        before_action :scc_upgrade, only: %i[upgrade], if: -> { @system.byos? }

        protected

        def scc_activate_product
          mode = find_mode
          unless mode.nil?
            # if system is byos or hybrid and there is a token
            # make a request to SCC
            logger.info "Activating product #{@product.product_string} to SCC"
            logger.info 'No token provided' if params[:token].blank?
            SccProxy.scc_activate_product(
              @system, @product, request.headers['HTTP_AUTHORIZATION'], params, mode
            )
            # if the system is PAYG and the registration code is valid for the extension,
            # then the system is hybrid
            # update the system to HYBRID mode if HYBRID MODE and system not HYBRID already
            @system.hybrid! if mode == 'hybrid' && @system.payg?

            logger.info "Product #{@product.product_string} successfully activated with SCC"
            InstanceVerification.update_cache(request.remote_ip, @system.login, @product.id)
          end
        end

        def find_mode
          if @system.byos?
            'byos'
          elsif !@product.free? && @product.extension? && params[:token].present?
            announce_base_product_hybrid 'hybrid'
            'hybrid'
          end
        end

        def announce_base_product_hybrid(mode)
          # in order for SCC to be able activate the extension (i.e. LTSS)
          # the system must be announced to SCC first
          base_prod = @system.products.find_by(product_type: :base)
          # the extensions must be the same version and arch
          # than base product
          if @system.payg? && base_prod.present?
            raise 'Incompatible extension product' unless @product.arch == base_prod.arch && @product.version == base_prod.version

            update_params_system_info mode
            SccProxy.announce_system_scc(
              "Token token=#{params[:token]}", params
            )
          end
        end

        def scc_upgrade
          logger.info "Upgrading system to product #{@product.product_string} to SCC"
          auth = nil
          auth = request.headers['HTTP_AUTHORIZATION'] if request.headers.include?('HTTP_AUTHORIZATION')
          mode = 'byos' if @system.byos?
          SccProxy.scc_upgrade(auth, @product, @system.login, mode, logger)
          logger.info "System #{@system.login} successfully upgraded with SCC"
        end

        def update_params_system_info(mode)
          params['hostname'] = @system.hostname
          params['proxy_byos_mode'] = mode
          params['scc_login'] = @system.login
          params['scc_password'] = @system.password
          params['hwinfo'] = JSON.parse(@system.system_information)
          params['instance_data'] = @system.instance_data
        end
      end

      Api::Connect::V4::Systems::ProductsController.class_eval do
        before_action :scc_deactivate_product, only: %i[destroy]

        protected

        def scc_deactivate_product
          auth = request.headers['HTTP_AUTHORIZATION']
          if @system.byos? && @product[:product_type] != 'base'
            SccProxy.deactivate_product_scc(auth, @product, @system.system_token, logger)
          elsif @system.hybrid? && @product.extension?
            # check if product is on SCC and
            # if it is -> de-activate it
            scc_hybrid_system_activations = SccProxy.get_scc_activations(
              headers, @system.system_token, @system.proxy_byos_mode, @system.login
            )
            if scc_hybrid_system_activations.map { |act| act['service']['product']['id'] == @product.id }.present?
              # if product is found on SCC, regardless of the state
              # it is OK to remove it from SCC
              SccProxy.deactivate_product_scc(auth, @product, @system.system_token, logger)
              make_system_payg(auth) if scc_hybrid_system_activations.reject { |act| act['service']['product']['id'] == @product.id }.blank?
            end
          end
          logger.info "Product '#{@product.friendly_name}' successfully deactivated from SCC"
        end

        def make_system_payg(auth)
          # if the system does not have more products activated on SCC
          # switch it back to payg
          # drop the just de-activated activation from the list to avoid another call to SCC
          # and check if there is any product
          SccProxy.deregister_system_scc(auth, @system)
          @system.payg!
        end
      end

      Api::Connect::V3::Systems::SystemsController.class_eval do
        before_action :scc_deregistration, only: %i[deregister]

        protected

        def scc_deregistration
          if @system.byos? || @system.hybrid?
            # byos and hybrid systems should get de-register from SCC
            SccProxy.deregister_system_scc(request.headers['HTTP_AUTHORIZATION'], @system)
          end
        end
      end

      ApplicationController.class_eval do
        # overwrite authenticate_system method
        # as BYOS in the cloud does not use SYSTEM_TOKEN headers
        def authenticate_system(skip_on_duplicated: false)
          authenticate_or_request_with_http_basic('RMT API') do |login, password|
            @systems = System.get_by_credentials(login, password)
            if @systems.present?
              # Return now if we just detected duplicates and we were told to skip on
              # this situation.
              return true if skip_on_duplicated && @systems.size > 1

              @system = get_system(@systems)
              if system_tokens_enabled? && request.headers.key?(ApplicationController::SYSTEM_TOKEN_HEADER)
                @system.update(last_seen_at: Time.zone.now)
                headers[ApplicationController::SYSTEM_TOKEN_HEADER] = @system.system_token
              elsif !@system.last_seen_at || @system.last_seen_at < 3.minutes.ago
                @system.touch(:last_seen_at)
              end
              true
            else
              logger.info _('Could not find system with login \"%{login}\" and password \"%{password}\"') %
                { login: login, password: password }
              error = ActionController::TranslatedError.new(N_('Invalid system credentials'))
              error.status = :unauthorized
              raise error
            end
          end
        end

        def get_system(systems)
          return nil if systems.blank?

          byos_systems_with_token = systems.select { |system| system.byos? && system.system_token }

          return systems.first if byos_systems_with_token.empty?

          system = byos_systems_with_token.first
          if byos_systems_with_token.length > 1
            # check for possible duplicated system_tokens
            duplicated_system_tokens = byos_systems_with_token.group_by { |sys| sys[:system_token] }.keys

            if duplicated_system_tokens.length > 1
              logger.info _('BYOS system with login \"%{login}\" authenticated and duplicated due to token (system tokens %{system_tokens}) mismatch') %
                { login: system.login, system_tokens: duplicated_system_tokens.join(',') }
            else
              # no different systems
              # first system is chosen
              logger.info _('BYOS system with login \"%{login}\" authenticated, system  token \"%{system_token}\"') %
                { login: system.login, system_token: system.system_token }
            end
          else
            logger.info _('BYOS system with login \"%{login}\" authenticated, system  token \"%{system_token}\"') %
              { login: system.login, system_token: system.system_token }
          end
          system
        end
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
# rubocop:enable Metrics/ModuleLength
