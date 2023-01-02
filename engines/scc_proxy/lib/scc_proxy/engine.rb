require 'json'
require 'net/http'

ANNOUNCE_URL = 'https://scc.suse.com/connect/subscriptions/systems'.freeze
ACTIVATE_PRODUCT_URL = 'https://scc.suse.com/connect/systems/products'.freeze
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

    def headers(auth, params, logger)
      if params && params.class != String
        @instance_id = get_instance_id(params, logger)
      else
        # if it is not JSON, it is the system_token already
        @instance_id = params
      end

      {
        'accept' => 'application/json,application/vnd.scc.suse.com.v4+json',
        'Content-Type' => 'application/json',
        'Authorization' => auth,
        ApplicationController::SYSTEM_TOKEN_HEADER => @instance_id
      }
    end

    def get_instance_id(params, logger)
      verification_provider = InstanceVerification.provider.new(
        logger,
        nil,
        nil,
        nil,
      )
      instance_id_keys = {
        'Amazon': 'instanceId',
        'Google': 'instance_id',
        'Microsoft': 'vmId'
      }
      instance_id_key = instance_id_keys[params['cloud_provider']]
      iid = verification_provider.parse_instance_data(params['instance_data'])
      iid[instance_id_key]
    end

    def prepare_scc_announce_request(uri_path, auth, params, logger)
      scc_request = Net::HTTP::Post.new(uri_path, headers(auth, params, logger))
      hw_info_keys = %i[cpus sockets hypervisor arch uuid cloud_provider]
      hw_info = params['hwinfo'].symbolize_keys.slice(*hw_info_keys)
      scc_request.body = {
        hostname: params['hostname'],
        hwinfo: hw_info,
        byos: @instance_id
      }.to_json
      scc_request
    end

    def prepare_scc_request(uri_path, product, auth, token, email, system_token, logger)
      scc_request = Net::HTTP::Post.new(uri_path, headers(auth, nil, logger))
      scc_request.body = {
        token: token,
        identifier: product.identifier,
        version: product.version,
        arch: product.arch,
        release_type: product.release_type,
        email: email || nil,
        byos: system_token
      }.to_json
      scc_request
    end

    def announce_system_scc(auth, params, logger)
      uri = URI.parse(ANNOUNCE_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_announce_request(uri.path, auth, params, logger)
      response = http.request(scc_request)
      response.error! unless response.code_type == Net::HTTPCreated

      JSON.parse(response.body)
    end

    def scc_activate_product(product, auth, token, email, system_token, logger)
      uri = URI.parse(ACTIVATE_PRODUCT_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_request(uri.path, product, auth, token, email, system_token, logger)
      http.request(scc_request)
    end

    def deactivate_product_scc(auth, product, params, logger)
      uri = URI.parse(DEREGISTER_PRODUCT_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = Net::HTTP::Delete.new(uri.path, headers(auth, params, logger))
      scc_request.body = {
        identifier: product.identifier,
        version: product.version,
        arch: product.arch
      }.to_json
      http.request(scc_request)
    end

    def deregister_system_scc(auth, params, logger)
      uri = URI.parse(DEREGISTER_SYSTEM_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = Net::HTTP::Delete.new(uri.path, headers(auth, params, logger))
      http.request(scc_request)
    end

    def parse_error(error_message, token = nil, email = nil)
      error_message = error_message[0..(error_message.index('json') - 1)].strip
      error_message = error_message.gsub(token, '').squish if token
      error_message = error_message.gsub(email, '').strip if email
      error_message
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def scc_check_subscription_expiration(headers, login, params, logger)
      auth = headers['HTTP_AUTHORIZATION'] if headers.include?('HTTP_AUTHORIZATION')
      uri = URI.parse(SYSTEMS_ACTIVATIONS_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = Net::HTTP::Get.new(uri.path, headers(auth, params, logger))
      response = http.request(scc_request)
      unless response.code_type == Net::HTTPOK
        logger.info "Could not get the system (#{login}) activations, error: #{response.message} #{response.code}"
        response.message = SccProxy.parse_error(response.message) if response.message.include? 'json'
        return { is_active: false, message: response.message }
      end
      scc_systems_activations = JSON.parse(response.body)
      return { is_active: false, message: 'No activations.' } if scc_systems_activations.empty?

      no_status_products_ids = scc_systems_activations.map do |act|
        act['service']['product']['id'] if (act['status'].nil? && act['expires_at'].nil?)
      end.flatten.compact
      return { is_active: true } unless no_status_products_ids.all?(&:nil?)

      active_products_ids = scc_systems_activations.map { |act| act['service']['product']['id'] if act['status'].casecmp('active').zero? }.flatten
      products = Product.where(id: active_products_ids)
      product_paths = products.map { |prod| prod.repositories.pluck(:local_path) }.flatten
      active_subscription = product_paths.any? { |path| headers['X-Original-URI'].include?(path) }
      if active_subscription
        { is_active: true }
      else
        # product not found in the active subscriptions, check the expired ones
        expired_products_ids = scc_systems_activations.map { |act| act['service']['product']['id'] unless act['status'].casecmp('active').zero? }.flatten
        if expired_products_ids.all?(&:nil?)
          return {
            is_active: false,
            message: 'Product not activated.'
          }
        end
        products = Product.where(id: expired_products_ids)
        product_paths = products.map { |prod| prod.repositories.pluck(:local_path) }.flatten
        expired_subscription = product_paths.any? { |path| headers['X-Original-URI'].include?(path) }
        if expired_subscription
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
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity
  end

  class Engine < ::Rails::Engine
    isolate_namespace SccProxy
    config.generators.api_only = true

    config.after_initialize do
      # replaces RMT registration for SCC registration
      Api::Connect::V3::Subscriptions::SystemsController.class_eval do
        def announce_system
          auth_header = nil
          auth_header = request.headers['HTTP_AUTHORIZATION'] if request.headers.include?('HTTP_AUTHORIZATION')
          if has_no_regcode?(auth_header)
            # no token sent to check with SCC
            # standard announce case
            @system = System.create!(hostname: params[:hostname], hw_info: HwInfo.new(hw_info_params))
          else
            response = SccProxy.announce_system_scc(auth_header, request.request_parameters, logger)
            @system = System.create!(
              login: response['login'],
              password: response['password'],
              hostname: params[:hostname],
              proxy_byos: true,
              hw_info: HwInfo.new(hw_info_params)
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

        protected

        def scc_activate_product
          logger.info "Activating product #{@product.product_string} to SCC"
          auth = request.headers['HTTP_AUTHORIZATION']
          if @system.proxy_byos
            iid = @system.hw_info.instance_data.match(%r{<document>(.*?)</document>}m)
            iid = iid.captures
            instance_id_keys = {
              'Amazon': 'instanceId',
              'Google': 'instance_id',
              'Microsoft': 'vmId'
            }
            iid_key = instance_id_keys[@system.hw_info.cloud_provider]
            iid  = JSON.parse(iid[0])[iid_key]
            response = SccProxy.scc_activate_product(@product, auth, params[:token], params[:email], iid, logger)
            unless response.code_type == Net::HTTPCreated
              error = JSON.parse(response.body)
              logger.info "Could not activate #{@product.product_string}, error: #{error['error']} #{response.code}"
              error['error'] = SccProxy.parse_error(error['error']) if error['error'].include? 'json'
              raise ActionController::TranslatedError.new(error['error'])
            end
            logger.info "Product #{@product.product_string} successfully activated with SCC"
            InstanceVerification.update_cache(request.remote_ip, @system.login, @product.id)
          end
        end
      end

      Api::Connect::V4::Systems::ProductsController.class_eval do
        before_action :scc_deactivate_product, only: %i[destroy]

        protected

        def scc_deactivate_product
          auth = request.headers['HTTP_AUTHORIZATION']
          if @system.proxy_byos && @product[:product_type] != 'base'
            response = SccProxy.deactivate_product_scc(auth, @product, request.request_parameters, logger)
            unless response.code_type == Net::HTTPOK
              error = JSON.parse(response.body)
              error['error'] = SccProxy.parse_error(error['error'], params[:token], params[:email]) if error['error'].include? 'json'
              logger.info "Could not de-activate product '#{@product.friendly_name}', error: #{error['error']} #{response.code}"
              raise ActionController::TranslatedError.new(error['error'])
            end
            logger.info "Product '#{@product.friendly_name}' successfully deactivated from SCC"
          end
        end
      end

      Api::Connect::V3::Systems::SystemsController.class_eval do
        before_action :scc_deregistration, only: %i[deregister]

        protected

        def scc_deregistration
          if @system.proxy_byos
            auth = request.headers['HTTP_AUTHORIZATION']
            response = SccProxy.deregister_system_scc(auth, @system.system_token, logger)
            unless response.code_type == Net::HTTPNoContent
              error = JSON.parse(response.body)
              logger.info "Could not de-activate system #{@system.login}, error: #{error['error']} #{response.code}"
              error['error'] = SccProxy.parse_error(error['error'], params[:token], params[:email]) if error['error'].include? 'json'
              raise ActionController::TranslatedError.new(error['error'])
            end
            logger.info 'System successfully deregistered from SCC'
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
