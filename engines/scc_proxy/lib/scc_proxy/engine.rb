require 'net/http'

ANNOUNCE_URL = 'https://scc.suse.com/connect/subscriptions/systems'.freeze
ACTIVATE_PRODUCT_URL = 'https://scc.suse.com/connect/systems/products'.freeze
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

module SccProxy
  class << self

    def headers(auth)
      {
        'accept' => 'application/json,application/vnd.scc.suse.com.v4+json',
        'Content-Type' => 'application/json',
        'Authorization' => auth
      }
    end

    def prepare_scc_announce_request(uri_path, auth, params)
      scc_request = Net::HTTP::Post.new(uri_path, headers(auth))
      hw_info_keys = %i[cpus sockets hypervisor arch uuid cloud_provider]
      hw_info = params['hwinfo'].symbolize_keys.slice(*hw_info_keys)
      scc_request.body = {
        hostname: params['hostname'],
        hwinfo: hw_info
      }.to_json
      scc_request
    end

    def prepare_scc_request(uri_path, product, auth, token, email)
      scc_request = Net::HTTP::Post.new(uri_path, headers(auth))
      scc_request.body = {
        token: token,
        identifier: product.identifier,
        version: product.version,
        arch: product.arch,
        release_type: product.release_type,
        email: email || nil
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

    def scc_activate_product(product, auth, token, email)
      uri = URI.parse(ACTIVATE_PRODUCT_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_request(uri.path, product, auth, token, email)
      http.request(scc_request)
    end
  end

  class Engine < ::Rails::Engine
    isolate_namespace SccProxy
    config.generators.api_only = true

    config.after_initialize do
      # replaces RMT registration for SCC registration
      Api::Connect::V3::Subscriptions::SystemsController.class_eval do
        def announce_system
          auth_header = request.headers['HTTP_AUTHORIZATION'] if request.headers.include?('HTTP_AUTHORIZATION')
          if has_no_regcode?(auth_header)
            # no token sent to check with SCC
            # standard announce case
            @system = System.create!(hostname: params[:hostname], hw_info: HwInfo.new(hw_info_params))
          else
            response = SccProxy.announce_system_scc(request.headers['HTTP_AUTHORIZATION'], request.request_parameters)
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
          logger.info auth_header
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
            response = SccProxy.scc_activate_product(@product, auth, params[:token], params[:email])
            unless response.code_type == Net::HTTPCreated
              error = JSON.parse(response.body)
              logger.info "Could not activate #{@product.product_string}, error: #{error['error']} #{response.code}"
              error['error'] = parse_error(error['error']) if error['error'].include? 'json'
              raise ActionController::TranslatedError.new(error['error'])
            end
            logger.info "Product #{@product.product_string} successfully activated with SCC"
            InstanceVerification.update_cache(request.remote_ip, @system.login, @product.id)
          end
        end

        def parse_error(error_message)
          error_message = error_message[0..(error_message.index('json') - 1)].strip
          error_message = error_message.gsub(params[:token], '').squish
          error_message.gsub(params[:email], '').strip
        end
      end
    end
  end
end
