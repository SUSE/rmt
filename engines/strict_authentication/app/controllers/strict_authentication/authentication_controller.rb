require_dependency 'strict_authentication/application_controller'

module StrictAuthentication
  class AuthenticationController < ::ApplicationController
    before_action :authenticate_system

    # This is the endpoint for nginx subrequest auth check
    def check
      request_uri = request.headers['X-Original-URI']
      auth_result = path_allowed?(request.headers['X-Original-URI'])
      logger.info "Authentication subrequest for #{request_uri} -- #{auth_result ? 'allowed' : 'denied'}"
      head auth_result ? :ok : :forbidden
    end

    protected

    def path_allowed?(path)
      return false if path.blank?
      return true if path =~ %r{/product\.license/}

      path = '/' + path.gsub(/^#{RMT::DEFAULT_MIRROR_URL_PREFIX}/, '')

      # Allow access to SLES 12 and 12-SP1 repos for systems migrating from SLES 11
      has_sles11 = @system.products.where(identifier: 'SUSE_SLES').first
      return true if (has_sles11 && (path =~ %r{/12/} || path =~ %r{/12-SP1/}))

      @system.repositories.pluck(:local_path).each do |allowed_path|
        return true if path =~ /^#{Regexp.escape(allowed_path)}/
      end

      false
    end
  end
end
