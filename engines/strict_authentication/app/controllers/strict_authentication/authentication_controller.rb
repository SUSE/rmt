require_dependency 'strict_authentication/application_controller'

module StrictAuthentication
  class AuthenticationController < ::ApplicationController
    before_action :authenticate_system

    # This is the endpoint for nginx subrequest auth check
    def check
      request_uri = request.headers['X-Original-URI']
      auth_result = path_allowed?(request.headers)
      logger.info "Authentication subrequest for #{request_uri} -- #{auth_result ? 'allowed' : 'denied'}"
      head auth_result ? :ok : :forbidden
    end

    protected

    def path_allowed?(headers)
      path = headers['X-Original-URI']
      return false if path.blank?

      return true if path =~ %r{/product\.license/}

      path = '/' + path.gsub(/^#{RMT::DEFAULT_MIRROR_URL_PREFIX}/, '')
      # Allow access to SLES 12 and 12-SP1 repos for systems migrating from SLES 11
      has_sles11 = @system.products.where(identifier: 'SUSE_SLES').first
      return true if (has_sles11 && (path =~ %r{/12/} || path =~ %r{/12-SP1/}))

      all_allowed_paths(headers).find { |allowed_path| path =~ /^#{Regexp.escape(allowed_path)}/ }
    end

    def all_allowed_paths(headers)
      # return all versions of the same product and arch
      # (that the system has available with that subscription)
      # in order to validate access not only for current product but others
      # feature requested by SUMA team
      # so they can check if a customer has access to other products and show those
      # to them or verify paths
      all_product_versions = @system.products.map { |p| Product.where(identifier: p.identifier, arch: p.arch) }.flatten
      allowed_paths = all_product_versions.map { |prod| prod.repositories.pluck(:local_path) }.flatten
      # for the SUMa PAYG offers, RMT access verification code allows access
      # to the SUMa Client Tools channels and SUMa Proxy channels
      # when product is SUMA_Server and PAYG or SUMA_Server and used as SCC proxy
      manager_prod = @system.products.any? do |p|
        manager = p.identifier.downcase.include?('manager-server')
        # SUMA 5.0 must have access to SUMA 4.3, 4.2 and so on
        micro = p.identifier.downcase.include?('sle-micro')
        instance_id_header = headers.fetch('X-Instance-Identifier', '').casecmp('suse-manager-server').zero?
        instance_version_header = headers.fetch('X-Instance-Version', '') == '5.0'
        manager || (micro && instance_id_header && instance_version_header)
      end

      if manager_prod
        # add all SUMA products paths
        manager_products = Product.where('identifier LIKE ?', '%manager%')
        manager_product_repo_paths = manager_products.map { |prod| prod.repositories.pluck(:local_path) }.flatten
        allowed_paths += manager_product_repo_paths
      end
      allowed_paths
    end
  end
end
