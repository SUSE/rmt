require 'base64'
require 'fileutils'

# rubocop:disable Metrics/ModuleLength
module InstanceVerification
  def self.update_cache(cache_entry, mode, registry: false)
    unless registry
      cache_path = InstanceVerification.get_cache_path(mode)
      InstanceVerification.write_cache_file(cache_path, cache_entry)
    end

    # update the registry cache every time
    InstanceVerification.write_cache_file(
      InstanceVerification.get_cache_path('registry'),
      cache_entry
    )
  end

  def self.build_cache_entry(remote_ip, system_login, params, mode, product)
    if mode == 'payg'
      [remote_ip, system_login, product.id].join('-')
    elsif mode == 'registry'
      [remote_ip, system_login].join('-')
    else
      # for byos or hybrid cache
      instance_data = params.fetch(:instance_data, '')
      iid = if instance_data.present?
              InstanceVerification.provider.new(nil, nil, nil, instance_data).instance_identifier
            else
              ''
            end
      encoded_reg_code = Base64.strict_encode64(params.fetch(:token, ''))
      "#{encoded_reg_code}-#{iid}-#{product.product_class}"
    end
  end

  def self.write_cache_file(cache_dir, cache_key)
    FileUtils.mkdir_p(cache_dir)
    FileUtils.touch(File.join(cache_dir, cache_key))
    Rails.logger.info "#{cache_dir} updated for #{cache_key}"
  end

  def self.get_cache_path(mode)
    if mode == 'byos'
      Rails.application.config.repo_byos_cache_dir
    elsif mode == 'hybrid'
      Rails.application.config.repo_hybrid_cache_dir
    elsif mode == 'payg'
      Rails.application.config.repo_payg_cache_dir
    else
      Rails.application.config.registry_cache_dir
    end
  end

  def self.get_cache_entries(mode)
    cache_path = InstanceVerification.get_cache_path(mode)
    Dir.children(cache_path)
  rescue SystemCallError
    Rails.logger.info "#{cache_path} does not exist"
    []
  end

  def self.reg_code_in_cache?(cache_key, mode)
    cache_entries = InstanceVerification.get_cache_entries(mode)
    cache_entries.find { |cache_entry| cache_entry.include?(cache_key) }
  end

  def self.remove_entry_from_cache(cache_key, mode)
    cache_path = InstanceVerification.get_cache_path(mode)
    full_path_cache_key = File.join(cache_path, cache_key)
    FileUtils.rm_f(full_path_cache_key)
  end

  def self.set_cache_active(cache_key, mode, registry = false) # rubocop:disable Style/OptionalBooleanParameter
    cache_key = [cache_key, 'active'].join('-') if ['byos', 'hybrid'].include?(mode)

    InstanceVerification.update_cache(cache_key, mode, registry: registry)
  end

  def self.set_cache_inactive(cache_key, mode)
    InstanceVerification.remove_entry_from_cache(cache_key, mode)
    cache_key = [cache_key, 'inactive'].join('-')
    InstanceVerification.update_cache(cache_key, mode)
  end

  def self.verify_instance(request, logger, system)
    return false unless request.headers.fetch('X-Instance-Data', false)

    base_product = system.products.find_by(product_type: 'base')
    return false unless base_product

    decoded_instance_data = Base64.decode64(request.headers['X-Instance-Data'].to_s)
    verification_provider = InstanceVerification.provider.new(
      logger,
      request,
      base_product.attributes.symbolize_keys.slice(:identifier, :version, :arch, :release_type),
      decoded_instance_data
    )
    cache_params = {}
    # we are checking the base product so we pick the first registration code
    # PAYG instances have no registration code
    cache_params = { token: Base64.decode64(system.pubcloud_reg_code.split(',')[0]), instance_data: decoded_instance_data } if system.pubcloud_reg_code.present?
    cache_key = InstanceVerification.build_cache_entry(
      request.remote_ip, system.login, cache_params, system.proxy_byos_mode, base_product
    )
    found_cache_entry = InstanceVerification.reg_code_in_cache?(cache_key, system.proxy_byos_mode)
    if found_cache_entry.present? && found_cache_entry.exclude?('-inactive')
      # only update registry cache key
      # even if the cache check was for PAYG/ repos cache
      # the registry cache should last longer than PAYG
      registry_cache_key = InstanceVerification.build_cache_entry(
        request.remote_ip, system.login, {}, 'registry', ''
      )
      InstanceVerification.update_cache(registry_cache_key, 'registry', registry: true)
      return true
    end

    is_valid = verification_provider.instance_valid?
    # update repository and registry cache
    InstanceVerification.set_cache_active(cache_key, system.proxy_byos_mode)
    # update the instance data when valid and not in the cache
    # before RMT 2.22, there was no need as the instance data was fresh from the client
    # after 2.22 we are using instance data from the DB and we need to refresh that data
    system.update_instance_data(decoded_instance_data)
    is_valid
  rescue InstanceVerification::Exception => e
    if system.byos?
      result = SccProxy.scc_check_subscription_expiration(
        request.headers, system, request.remote_ip, false, cache_params, base_product
      )
      if result[:is_active]
        # update the cache for the base product
        InstanceVerification.set_cache_active(cache_key, 'byos')
        system.update_instance_data(decoded_instance_data)
        return true
      end
      # if can not get the activations, set the cache inactive
      InstanceVerification.set_cache_inactive(cache_key, system.proxy_byos_mode)
    end
    ZypperAuth.zypper_auth_message(request, system, verification_provider, e.message)
    false
  rescue StandardError => e
    logger.error('Unexpected instance verification error has occurred:')
    logger.error(e.message)
    logger.error("System login: #{system.login}, IP: #{request.remote_ip}")
    logger.error('Backtrace:')
    logger.error(e.backtrace)
    false
  end

  class Engine < ::Rails::Engine
    isolate_namespace InstanceVerification
    config.generators.api_only = true

    config.after_initialize do
      Api::Connect::V3::Subscriptions::SystemsController.class_eval do
        after_action :save_instance_data, only: %i[announce_system]

        # store IID for later product activation checks
        def save_instance_data
          return true unless (@system && params[:instance_data])
          @system.instance_data = params[:instance_data]
          @system.save!
        end
      end

      Api::Connect::V3::Systems::ProductsController.class_eval do
        before_action :verify_product_activation, only: %i[activate]
        before_action :verify_base_product_upgrade, only: %i[upgrade]

        def find_product
          product = Product.find_by(
            identifier: params[:identifier],
            version: Product.clean_up_version(params[:version]),
            arch: params[:arch]
          )

          raise ActionController::TranslatedError.new('Migration target not found') unless product
          product
        end

        def find_subscription(base_product, logger, request)
          # this method is needed because
          # https://bugzilla.suse.com/show_bug.cgi?id=1236816
          # https://bugzilla.suse.com/show_bug.cgi?id=1236836
          product_hash = {
            identifier: base_product.identifier,
            version: base_product.version,
            arch: base_product.arch,
            release_type: base_product.release_type
          }
          begin
            add_on_product_class = InstanceVerification.provider.new(
              logger,
              request,
              product_hash,
              @system.instance_data
              ).add_on
          rescue InstanceVerification::Exception => e
            logger.error("Could not find subscription: #{e.message}")
            raise ActionController::TranslatedError.new("Could not find subscription: #{e.message}")
          end
          # add_on_product_class, if present, is the real product class
          # i.e. in the case of SUMA, it would be SUMA product class
          # not the SUMA base product's product class (Micro)
          product_class = add_on_product_class.presence || base_product.product_class
          # it returns the first subscription that matches
          # even if there are more subscriptions that match
          Subscription.joins(:product_classes).find_by(
            subscription_product_classes: {
              product_class: product_class
            }
          )
        end

        def verify_product_activation
          product = find_product

          if product.base?
            verify_base_product_activation(product)
          elsif !product.free? && params[:token].blank?
            verify_payg_extension_activation!(product)
          end
        rescue InstanceVerification::Exception => e
          unless @system.byos?
            # BYOS instances that use RMT as a proxy are expected to fail the
            # instance verification check, however, PAYG instances may send registration
            # code, as such, instance verification engine checks for those BYOS
            # instances once instance verification has failed
            logger.error "Instance verification failed: #{e.message}"
            raise ActionController::TranslatedError.new('Instance verification failed: %{message}' % { message: e.message })
          end
        rescue StandardError => e
          logger.error('Unexpected instance verification error has occurred:')
          logger.error(e.message)
          logger.error("System login: #{@system.login}, IP: #{request.remote_ip}")
          logger.error('Backtrace:')
          logger.error(e.backtrace)
          raise ActionController::TranslatedError.new('Unexpected instance verification error has occurred')
        end

        def verify_payg_extension_activation!(product)
          return if product.free?

          base_product = @system.products.find_by(product_type: :base)
          subscription = find_subscription(base_product, logger, request)
          # This error would occur only if there's a problem with subscription setup on SCC side
          raise InstanceVerification::Exception, "Can't find a subscription for base product #{base_product.product_string}" unless subscription

          allowed_product_classes = subscription.product_classes.pluck(:product_class)

          unless allowed_product_classes.include?(product.product_class)
            raise InstanceVerification::Exception.new(
              'The product is not available for this instance'
            )
          end
          logger.info "Product #{product.product_string} available for this instance"
          cache_key = InstanceVerification.build_cache_entry(request.remote_ip, @system.login, nil, 'payg', product)
          InstanceVerification.update_cache(cache_key, 'payg')
        end

        def verify_base_product_activation(product)
          InstanceVerification.provider.new(
            logger,
            request,
            params.permit(:identifier, :version, :arch, :release_type).to_h,
            @system.instance_data
          ).instance_valid?
          # we use the token sent from the client if present
          # instead of the value stored in the DB
          params[:instance_data] = @system.instance_data
          cache_key = InstanceVerification.build_cache_entry(
            request.remote_ip,
            @system.login,
            params,
            @system.proxy_byos_mode,
            product
          )
          InstanceVerification.set_cache_active(cache_key, @system.proxy_byos_mode)
        end

        # Verify that the base product doesn't change in the offline migration
        def verify_base_product_upgrade
          upgrade_product = find_product
          return unless upgrade_product.base?

          activated_bases = @system.products.where(product_type: 'base')
          activated_bases.each do |base_product|
            base_product_subscription = find_subscription(base_product, logger, request)
            return true if base_product_subscription&.products&.include?(upgrade_product)
          end

          raise ActionController::TranslatedError.new('Migration target not allowed on this instance type')
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
