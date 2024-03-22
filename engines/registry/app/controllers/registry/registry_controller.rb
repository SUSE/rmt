module Registry
  class RegistryController < ::ApplicationController
    REGISTRY_SERVICE = 'SUSE Linux OCI Registry'.freeze
    REGISTRY_API_VERSION = 'registry/2.0'.freeze

    before_action :set_requested_scopes, except: [ :catalog ]
    before_action :basic_auth, except: [ :catalog ]
    before_action :catalog_token_auth, only: [ :catalog ]

    rescue_from Exception, with: :handle_exceptions

    # AuthZ handler
    # AuthZ will validate which of the requested scope policies are fulfilled
    # with the current login access and prepare the token to be sent back to the client
    def authorize
      token = Registry::AccessToken.new(@client&.account, params['service'], @requested_scopes.map { |s| s.granted(client: @client) }).token
      render json: { token: token }, status: :ok
    end

    # Catalog handler
    # Returns a Distribution Registry HTTP API V2 - compatible repository catalog as defined in
    # https://distribution.github.io/distribution/spec/api/#listing-repositories
    def catalog
      access_scope = Registry::AccessScope.parse(['registry:catalog:*'])
      repos = access_scope.allowed_paths(System.find_by(login: @client&.account))
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
      unless raw_scopes.empty?
        @requested_scopes = raw_scopes.map do |scope| #.filter_map do |scope|
          Registry::AccessScope.parse(scope)
        end
      end
      logger.info("Requested scopes: #{@requested_scopes.map(&:to_s)}")
    end

    # AuthN handler
    # https://docs.docker.com/registry/spec/auth/jwt/#getting-a-bearer-token
    def basic_auth
      # skip authentication if this is not a login request
      return unless request.authorization

      authenticate_or_request_with_http_basic('SUSE Registry Authentication') do |login, password|
        begin
          @client = Registry::AuthenticatedClient.new(login, password)
        rescue StandardError
          logger.info _('Could not find system with login \"%{login}\" and password \"%{password}\"') %
            { login: login, password: password }
          error = ActionController::TranslatedError.new(N_('Invalid registry credentials'))
          error.status = :unauthorized
          raise error
        end

        true
      end
    end

    def catalog_token_auth
      authenticate_or_request_with_http_token(authorize_api_registry_url, 'authentication required') do |token|
        begin
          @client = Registry::CatalogClient.new(token)
        rescue JWT::DecodeError
          logger.info _('Invalid token')
          error = ActionController::TranslatedError.new(N_('Invalid registry token'))
          error.status = :unauthorized
          raise error
        end

        @client.authorized_for_catalog?
      end
    end

    # is called by authenticate_or_request_with_http_token when client provides no token
    def request_http_token_authentication(realm = authorize_api_registry_url, message = 'authentication required')
      headers['WWW-Authenticate'] = [
        %(Bearer realm="#{realm.delete('"')}"),
        %(service="#{REGISTRY_SERVICE.delete('"')}"),
        %(scope="registry:catalog:*"),
        %(error="insufficient_scope")
      ].join(',')

      render json: { errors: [ code: 'UNAUTHORIZED', details: nil, message: message] }, status: :unauthorized
    end
  end
end
