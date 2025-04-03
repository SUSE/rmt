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

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def path_allowed?(headers)
      path = headers['X-Original-URI']
      return false if path.blank?

      return true if path =~ %r{/product\.license/}

      path = '/' + path.gsub(/^#{RMT::DEFAULT_MIRROR_URL_PREFIX}/, '')
      # pp "PATH #{path}"
      # Allow access to SLES 12 and 12-SP1 repos for systems migrating from SLES 11
      has_sles11 = @system.products.where(identifier: 'SUSE_SLES').first
      # pp "SLEEE #{has_sles11}"
      # pp has_sles11 && (path =~ %r{/12/} || path =~ %r{/12-SP1/})
      return true if (has_sles11 && (path =~ %r{/12/} || path =~ %r{/12-SP1/}))

      found_path = all_allowed_paths(headers).find { |allowed_path| path =~ /^#{Regexp.escape(allowed_path)}/ }
      return false if found_path.blank?

      return true if found_path.present? && @system.payg?

      if @system.hybrid? || @system.byos?
        # check if the path is paid for hybrid or byos instances
        base_product = @system.products.find_by(product_type: 'base')
        verification_provider = InstanceVerification.provider.new(
          logger,
          request,
          base_product.attributes.symbolize_keys.slice(:identifier, :version, :arch, :release_type),
          Base64.decode64(request.headers['X-Instance-Data'].to_s) # instance data
        )
        paid_extensions = @system.products.select { |prod| prod if !prod.free && prod.product_type == 'extension' }
        paid_extensions.each do |paid_extension|
          repos_paths = paid_extension.repositories.pluck(:local_path)
          repos_paths.each do |repo_path|
            if found_path == repo_path
              logger.info "verifying paid extension #{paid_extension.identifier}"
              result = SccProxy.scc_check_subscription_expiration(request.headers, @system, paid_extension.product_class)
              Rails.logger.info "Result from check subscription with SCC #{result}"
              return true if result[:is_active]

              # if the paid extension is not on SCC
              # and the system is hybrid, we return true for the path
              # to check if it is included in the system
              # with the instance metadata
              # i.e. Live Patching in SLES4SAP
              return true if result[:message] == 'Product not activated.' && @system.hybrid?

              ZypperAuth.zypper_auth_message(request, @system, verification_provider, result[:message])
              return false
            end
          end
        end
        if @system.byos?
          result = SccProxy.scc_check_subscription_expiration(request.headers, @system, base_product.product_class)
          Rails.logger.info "Result from check subscription with SCC #{result}"
          return true if result[:is_active]

          ZypperAuth.zypper_auth_message(request, @system, verification_provider, result[:message])
          false
        else
          # system is hybrid but the path is not a paid extension
          # or path is not free and belongs to the base product repositories
          # i.e. HA for SAP
          # check if it belongs to the free products repositories list
          true
        end
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity

    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def all_allowed_paths(headers)
      # return all versions of the same product and arch
      # (that the system has available with that subscription)
      # in order to validate access not only for current product but others
      # feature requested by SUMA team
      # so they can check if a customer has access to other products and show those
      # to them or verify paths
      all_product_versions = @system.products.map { |p| Product.where(identifier: p.identifier, arch: p.arch) }.flatten
      allowed_paths = all_product_versions.map { |prod| prod.repositories.pluck(:local_path) }.flatten
      # Allow SLE Micro to access all free SLES repositories
      sle_micro = @system.products.any? { |p| p.identifier.downcase.include?('micro') }
      if sle_micro
        system_products_archs = @system.products.pluck(:arch)
        product_free_sles_modules_only = Product.where(
          "(lower(identifier) like 'sle-module%' or lower(identifier) like 'packagehub')
           and lower(identifier) not like '%sap%'
           and arch = '#{system_products_archs.first}'
           and free = 1"
          )
      end
      same_arch = product_free_sles_modules_only.any? { |p| system_products_archs.include?(p.arch) } if product_free_sles_modules_only.present?
      allowed_paths += product_free_sles_modules_only.map { |prod| prod.repositories.pluck(:local_path) }.flatten if same_arch

      # for the SUMa PAYG offers, RMT access verification code allows access
      # to the SUMa Client Tools channels and SUMa Proxy channels
      # when product is SUMA_Server and PAYG or SUMA_Server and used as SCC proxy
      manager_prod = @system.products.any? do |p|
        manager = p.identifier.downcase.include?('manager-server')
        # SUMA 5.0 must have access to SUMA 4.3, 4.2 and so on
        micro = p.identifier.downcase.include?('micro')
        instance_id_header = headers.fetch('X-Instance-Identifier', '').casecmp('suse-manager-server').zero?
        instance_version_header = headers.fetch('X-Instance-Version', '0').split('.')[0] >= '5'
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
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/PerceivedComplexity
  end
end
