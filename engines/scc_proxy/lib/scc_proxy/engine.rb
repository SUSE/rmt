require 'net/http'

REGISTER_URL = 'https://scc.suse.com/connect/subscriptions/systems'
SYSTEM_SUBSCRIPTION_URL = 'https://scc.suse.com/connect/systems/subscriptions'
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
]

module SccProxy
  class << self

    def prepare_scc_registration_request(uri_path, auth, params)
      request_header = {
        accept: 'application/json,application/vnd.scc.suse.com.v4+json'
        Content-Type: 'application/json'
	Authorization: auth
      }
      scc_request = Net::HTTP::Post.new(uri_path, request_header)
      hw_info_keys = %i[cpus sockets hypervisor arch uuid cloud_provider]
      hw_info = params['hwinfo'].symbolize_keys.slice(*hw_info_keys)
      scc_request.body = {
        hostname: params['hostname'],
	hwinfo: hw_info
      }.to_json
      scc_request
    end

    def register_system_scc(auth, params)
      uri = URI.parse(REGISTER_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      scc_request = prepare_scc_registration_request(uri.path, auth, params)
      response = http.request(scc_request)
      # raise exception if resource not created
      response.error! unless response.code_type == Net::HTTPCreated

      JSON.parse(response.body)
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
          auth_header ||= '='
          auth_header = auth_header[auth_header.index('=') + 1..-1]
          if auth_header.empty?
            # no token sent to check with SCC
            @system = System.create!(hostname: params[:hostname], hw_info: HwInfo.new(hw_info_params))
          else
            response = SccProxy.register_system_scc(request.headers['HTTP_AUTHORIZATION'], request.request_parameters)
            hw_info = hw_info_params
            hw_info[:proxy_byos] = true
            @system = System.create!(
              login: response['login'],
              password: response['password'],
              hostname: params[:hostname],
              hw_info: HwInfo.new(hw_info)
            )
            # SccProxy.update_subscription(@system.login, @system.password, logger)
          end
          logger.info("System '#{@system.hostname}' announced")
          respond_with(@system, serializer: ::V3::SystemSerializer, location: nil)
        rescue *NET_HTTP_ERRORS => e
          logger.error(
            "Could not register system with regcode #{auth_header} " \
            "to SCC: #{e.message}"
          )
          if e.message.include? '401'
            # same message and status than SUSEConnect cli output
            # check why it is 422 and not 401
            status = 422
            message = 'No subscription with this Registration Code found'
          else
            message = e.message
            status = e.message[0..(message.index(' ') - 1)].to_i
          end
          render json: { type: 'error', error: message }, status: status, location: nil
        end
      end
    end
  end
end
