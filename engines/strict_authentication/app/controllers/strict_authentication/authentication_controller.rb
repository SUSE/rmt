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

      all_allowed_paths.find { |allowed_path| path =~ /^#{Regexp.escape(allowed_path)}/ }
    end

    def all_allowed_paths
      # return all versions of the same product and arch
      # (that the system has available with that subscription)
      # in order to validate access not only for current product but others
      # feature requested by SUMA team
      # so they can check if a customer has access to other products and show those
      # to them or verify paths
      all_product_versions = @system.products.map { |p| Product.where(identifier: p.identifier, arch: p.arch) }.flatten
      all_product_versions = all_product_versions.map { |prod| prod.repositories.pluck(:local_path) }.flatten
      manager_prod = @system.products.any? { |p| p.identifier.include?('manager') }

      if manager_prod
        # add all SUMA products paths
        manager_products = Product.where('identifier LIKE ?', '%manager%')
        manager_product_repo_paths = manager_products.map { |prod| prod.repositories.pluck(:local_path) }.flatten
        all_product_versions += manager_product_repo_paths
      end
      all_product_versions
    end
  end
end
