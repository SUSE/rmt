require_dependency 'strict_authentication/application_controller'

module StrictAuthentication
  class AuthenticationController < ::ApplicationController
    before_action :authenticate_system

    # This is the endpoint for nginx subrequest auth check
    def check
      head path_allowed?(request.headers['X-Original-URI']) ? :ok : :forbidden
    end

    protected

    def path_allowed?(path)
      return false if path.blank?
      return true if path =~ %r{/product\.license/}

      path = '/' + path.gsub(/^#{RMT::DEFAULT_MIRROR_URL_PREFIX}/, '')

      @system.repositories.pluck(:local_path).each do |allowed_path|
        return true if path =~ /^#{allowed_path}/
      end

      false
    end
  end
end
