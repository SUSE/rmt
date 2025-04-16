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

# rubocop:disable Metrics/ModuleLength
module SccProxy
  class << self
    def headers(auth, system_token)
      {
        'accept' => 'application/json,application/vnd.scc.suse.com.v4+json',
        'Content-Type' => 'application/json',
        'Authorization' => auth,
        ApplicationController::SYSTEM_TOKEN_HEADER => system_token
      }
    end

    def prepare_scc_announce_request(uri_path, auth, params, system_token)
      scc_request = Net::HTTP::Post.new(uri_path, headers(auth, system_token))
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
      scc_request = Net::HTTP::Post.new(uri_path, headers(auth, params[:system_token]))
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

    def prepare_scc_upgrade_request(uri_path, product, auth, system_token, mode)
      scc_request = Net::HTTP::Put.new(uri_path, headers(auth, system_token))
      scc_request.body = {
        identifier: product.identifier,
        version: product.version,
        arch: product.arch,
        byos_mode: mode
      }.to_json
      scc_request
    end

    def announce_system_scc(auth, params, system_token)
      uri = URI.parse(ANNOUNCE_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_announce_request(uri.path, auth, params, system_token)
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
        # if product can not be activated
        # set the registration code as invalid in the cache
        cache_key = InstanceVerification.build_cache_entry(nil, nil, Base64.strict_encode64(params[:token]), mode, product)
        InstanceVerification.set_cache_inactive(cache_key, mode)
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

    def get_scc_activations(auth, system)
      uri = URI.parse(SYSTEMS_ACTIVATIONS_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      uri.query = URI.encode_www_form({ byos_mode: system.proxy_byos_mode })
      scc_request = Net::HTTP::Get.new(uri.path, headers(auth, system.system_token))
      response = http.request(scc_request)
      unless response.code_type == Net::HTTPOK
        Rails.logger.info "Could not get the system (#{system.login}) activations, error: #{response.message} #{response.code}"
        raise ActionController::TranslatedError.new(response.body)
      end
      JSON.parse(response.body)
    end

    def product_class_access(scc_systems_activations, product_class)
      expired_products_classes = scc_systems_activations.map do |act|
        act_product_class = act['service']['product']['product_class']
        act_product_class if act_product_class == product_class && act['status'].casecmp('expired').zero?
      end.compact.flatten
      message = if expired_products_classes.empty?
                  'Product not activated.'
                elsif expired_products_classes.include?(product_class)
                  'Subscription expired.'
                end
      { is_active: false, message: message }
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def scc_check_subscription_expiration(headers, system, product_class = nil)
      auth = headers.fetch('HTTP_AUTHORIZATION', '')
      scc_systems_activations = SccProxy.get_scc_activations(auth, system)
      return { is_active: false, message: 'No activations.' } if scc_systems_activations.empty?

      status_products_classes = if system.byos?
                                  scc_systems_activations.map do |act|
                                    product = act['service']['product']
                                    if product['product_class'] == product_class && (product['free'] || (!act['status'].nil? && act['status'].casecmp('active').zero?)) # rubocop:disable Layout/LineLength
                                      # free module or (paid extension or base product))
                                      true
                                    end
                                  end.compact
                                elsif system.hybrid?
                                  scc_systems_activations.map do |act|
                                    product = act['service']['product']
                                    true if act['status'].casecmp('active').zero? && product['product_class'] == product_class
                                  end.compact
                                end

      return { is_active: true } if !status_products_classes.empty? && status_products_classes.all?(true)

      SccProxy.product_class_access(scc_systems_activations, product_class)
    rescue StandardError
      { is_active: false, message: 'Could not check the activations from SCC' }
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    def scc_upgrade(auth, product, system, logger)
      uri = URI.parse(SYSTEM_PRODUCTS_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_upgrade_request(uri.path, product, auth, system.system_token, system.proxy_byos_mode)
      response = http.request(scc_request)
      unless response.code_type == Net::HTTPCreated
        logger.info "Could not upgrade the system (#{system.login}), error: #{response.message} #{response.code}"
        response.message = SccProxy.parse_error(response.message) if response.message.include? 'json'
        raise ActionController::TranslatedError.new(response.body)
      end
      response
    end
  end

  class Engine < ::Rails::Engine
    isolate_namespace SccProxy
    config.generators.api_only = true

    config.after_initialize do
      # replaces RMT registration for SCC registration
      Api::Connect::V3::Subscriptions::SystemsController.class_eval do
        def announce_system
          auth_header = request.headers.fetch('HTTP_AUTHORIZATION', nil)
          system_information = hwinfo_params[:hwinfo].to_json
          instance_data = params.fetch(:instance_data, nil)
          system_token = InstanceVerification.provider.new(nil, nil, nil, params['instance_data']).instance_identifier
          if has_no_regcode?(auth_header)
            # no token sent to check with SCC
            # standard announce case
            @system = System.create!(
              hostname: params[:hostname],
              system_information: system_information,
              proxy_byos_mode: :payg,
              instance_data: instance_data,
              system_token: system_token
            )
          else
            request.request_parameters['proxy_byos_mode'] = 'byos'
            response = SccProxy.announce_system_scc(auth_header, request.request_parameters, system_token)
            @system = System.create!(
              system_token: system_token,
              scc_system_id: response['id'],
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
          product_hash = @product.attributes.symbolize_keys.slice(:identifier, :version, :arch)
          unless InstanceVerification.provider.new(logger, request, product_hash, @system.instance_data).allowed_extension?
            error = ActionController::TranslatedError.new(N_('Product not supported for this instance'))
            error.status = :forbidden
            raise error
          end
          mode = find_mode
          unless mode.nil?
            # check cache first
            # if system is byos or hybrid and
            # there is a token
            # make a request to SCC
            logger.info "Activating product #{@product.product_string} to SCC"
            logger.info 'No token provided' if params[:token].blank?
            # take care of old hybrid systems that do not have a system_token
            # all (old and new) byos have a system token
            update_system_token if @system.system_token.nil?

            params[:system_token] = @system.system_token
            SccProxy.scc_activate_product(@system, @product, request.headers['HTTP_AUTHORIZATION'], params, mode)
            logger.info "Product #{@product.product_string} successfully activated with SCC"
            # if the system is PAYG and the registration code is valid for the extension,
            # then the system is hybrid
            # update the system to HYBRID mode if HYBRID MODE and system not HYBRID already
            @system.hybrid! if mode == 'hybrid' && @system.payg?

            encoded_reg_code = Base64.strict_encode64(params[:token])
            InstanceVerification.update_cache(
              InstanceVerification.build_cache_entry(nil, nil, encoded_reg_code, mode, @product),
              mode
            )
          end
          update_pubcloud_reg_code(encoded_reg_code)
        rescue *NET_HTTP_ERRORS => e
          logger.error(
            "Could not activate product for system with regcode #{params[:token]}" \
              "to SCC: #{e.message}"
          )
          render json: { type: 'error', error: e.message }, status: status_code(e.message), location: nil
        end

        def update_pubcloud_reg_code(encoded_reg_code)
          return if encoded_reg_code.nil?

          return if @system.pubcloud_reg_code&.include?(encoded_reg_code) # the reg code is already in that system

          # the encoded_reg code is not part of the pubcloud_reg_code of that system
          encoded_reg_code = @system.pubcloud_reg_code + ',' + encoded_reg_code if @system.pubcloud_reg_code.present?

          @system.update(pubcloud_reg_code: encoded_reg_code)
        end

        def update_system_token
          iid = InstanceVerification.provider.new(nil, nil, nil, @system.instance_data).instance_identifier
          @system.update!(system_token: iid)
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
            params['system_token'] = @system.system_token.presence || params.fetch('system_token', '')
            Rails.logger.info 'No system token' if params['system_token'].blank?

            SccProxy.announce_system_scc("Token token=#{params[:token]}", params, params['system_token'])
          end
        end

        def status_code(error_message)
          error_message[0..(error_message.index(' ') - 1)].to_i
        end

        def scc_upgrade
          logger.info "Upgrading system to product #{@product.product_string} to SCC"
          auth = request.headers.fetch('HTTP_AUTHORIZATION', '')
          SccProxy.scc_upgrade(auth, @product, @system, logger)
          logger.info "System #{@system.login} successfully upgraded with SCC"
        end

        def update_params_system_info(mode)
          params['hostname'] = @system.hostname
          params['proxy_byos_mode'] = mode
          params['scc_login'] = @system.login
          params['scc_password'] = @system.password
          params['hwinfo'] = JSON.parse(@system.system_information)
          params['instance_data'] = @system.instance_data
          params['system_token'] = @system.system_token
        end
      end

      Api::Connect::V4::Systems::ProductsController.class_eval do
        before_action :scc_deactivate_product, only: %i[destroy]

        protected

        def scc_deactivate_product
          auth = request.headers.fetch('HTTP_AUTHORIZATION', '')
          if @system.byos? && @product[:product_type] != 'base'
            SccProxy.deactivate_product_scc(auth, @product, @system.system_token, logger)
          elsif @system.hybrid? && @product.extension?
            # check if product is on SCC and
            # if it is -> de-activate it
            scc_hybrid_system_activations = SccProxy.get_scc_activations(auth, @system)
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
end
# rubocop:enable Metrics/ModuleLength
