module Registry
  class RegistryController < Registry::ApplicationController
    REGISTRY_SERVICE = 'SUSE Linux OCI Registry'.freeze
    REGISTRY_API_VERSION = 'registry/2.0'.freeze

    before_action :set_requested_scopes, except: [ :catalog ]
    before_action :basic_auth, except: [ :catalog ]
    before_action :catalog_token_auth, only: [ :catalog ]

    # AuthZ handler
    # AuthZ will validate which of the requested scope policies are fulfilled
    # with the current login access and prepare the token to be sent back to the client
    def authorize
      token = AccessToken.new(@client&.account, params['service'], @requested_scopes.map { |s| s.granted(client: @client) }).token
      render json: { token: token }, status: :ok
    end

    # Catalog handler
    # Returns a Distribution Registry HTTP API V2 - compatible repository catalog as defined in
    # https://distribution.github.io/distribution/spec/api/#listing-repositories
    def catalog
      access_scope = AccessScope.parse('registry:catalog:*')
      origin_url = request.protocol + request.host
      repos = access_scope.allowed_paths(System.find_by(login: @client&.account), origin_url)
      logger.debug("Returning #{repos.size} repos for client #{@client}")

      response.set_header('Docker-Distribution-Api-Version', REGISTRY_API_VERSION)
      render json: { repositories: repos }, status: :ok
    end

    private

    # Support multiple scopes. Podman & Docker handle this differently
    #   - Podman sends multiple querystrings with the same name.
    #   - Docker sends space-separated values in only one query string.
    # This should normalize everything
    def set_requested_scopes
      raw_scopes = CGI.parse(request.env['QUERY_STRING']).fetch('scope', [])
      .join(' ')
      .split
      .map(&:presence)
      .compact
      .map(&:downcase)

      @requested_scopes = []
      @requested_scopes = raw_scopes.map { |scope| AccessScope.parse(scope) } unless raw_scopes.empty?

      logger.info("Requested scopes: #{@requested_scopes.map(&:to_s)}")
    end

    # AuthN handler
    # https://docs.docker.com/registry/spec/auth/jwt/#getting-a-bearer-token
    def basic_auth
      # skip authentication if this is not a login request
      return unless request.authorization

      authenticate_or_request_with_http_basic('SUSE Registry Authentication') do |login, password|
        begin
          @client = Registry::AuthenticatedClient.new(login, password, request.remote_ip)
        rescue StandardError
          logger.info _('Could not find system with login \"%{login}\" and password \"%{password}\"') %
            { login: login, password: password }
          error = ActionController::TranslatedError.new(N_('Please, re-authenticate'))
          error.status = :unauthorized
          render json: { error: error.message }.to_json, status: :unauthorized
        end

        true
      end
    end

    def catalog_token_auth
      authenticate_or_request_with_http_token(authorize_url, 'authentication required') do |token|
        begin
          @client = CatalogClient.new(token)
        rescue JWT::DecodeError
          logger.info _('Invalid token')
          error = ActionController::TranslatedError.new(N_('Please, run cloudguestregistryauth'))
          error.status = :unauthorized
          render json: { error: error.message }.to_json, status: :unauthorized
          return
        end

        @client.authorized_for_catalog?
      end
    end

    # is called by authenticate_or_request_with_http_token when client provides no token
    def request_http_token_authentication(realm = authorize_url, message = 'authentication required')
      www_authenticate = [
        %(Bearer realm="#{realm.delete('"')}"),
        %(service="#{REGISTRY_SERVICE.delete('"')}"),
        %(scope="registry:catalog:*")
      ]

      www_authenticate << %(error="insufficient_scope") if request.authorization

      headers['WWW-Authenticate'] = www_authenticate.join(',')

      render json: { errors: [ code: 'UNAUTHORIZED', details: nil, message: message] }, status: :unauthorized
    end
  end
end
