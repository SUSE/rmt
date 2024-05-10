require 'fileutils'

module InstanceVerification
  def self.update_cache(remote_ip, system_login, product_id, is_byos: false, registry: false) # rubocop:disable Lint/UnusedMethodArgument
    # TODO: BYOS scenario
    # to be addressed on a different PR
    unless registry
      # write repository cache
      repository_cache_path = InstanceVerification.repository_cache_path(remote_ip, system_login, product_id)
      InstanceVerification.write_cache_file(repository_cache_path) unless registry
    end

    # write registry cache
    registry_cache_path = InstanceVerification.registry_cache_path(remote_ip, system_login)
    InstanceVerification.write_cache_file(registry_cache_path)
  end

  def self.write_cache_file(cache_path)
    Dir.mkdir(File.dirname(cache_path)) unless File.directory?(File.dirname(cache_path))

    FileUtils.touch(cache_path)
  end

  def self.repository_cache_path(remote_ip, system_login, product_id)
    File.join(
      Rails.application.config.repo_cache_dir,
      InstanceVerification.build_cache_key(remote_ip, system_login, product_id: product_id)
    )
  end

  def self.registry_cache_path(remote_ip, system_login)
    File.join(
      Rails.application.config.registry_cache_dir,
      InstanceVerification.build_cache_key(remote_ip, system_login)
    )
  end

  def self.remove_registry_cache(remote_ip, system_login)
    registry_cache_path = InstanceVerification.registry_cache_path(remote_ip, system_login)
    File.unlink(registry_cache_path) if File.exist?(registry_cache_path)
  end

  def self.build_cache_key(remote_ip, system_login, product_id: nil)
    cache_key = [remote_ip, system_login]
    cache_key.append(product_id) unless product_id.nil?

    cache_key.join('-')
  end

  def self.verify_instance(request, logger, system)
    return false unless request.headers['X-Instance-Data']

    instance_data = Base64.decode64(request.headers['X-Instance-Data'].to_s)
    base_product = system.products.find_by(product_type: 'base')
    return false unless base_product

    # check the cache for the system (20 min)
    cache_path = InstanceVerification.repository_cache_path(request.remote_ip, system.login, base_product.id)
    if File.exist?(cache_path)
      # only update registry cache key
      InstanceVerification.update_cache(request.remote_ip, system.login, nil, is_byos: system.proxy_byos, registry: true)
      return true
    end

    verification_provider = InstanceVerification.provider.new(
      logger,
      request,
      base_product.attributes.symbolize_keys.slice(:identifier, :version, :arch, :release_type),
      instance_data
    )

    is_valid = verification_provider.instance_valid?
    # update repository and registry cache
    InstanceVerification.update_cache(request.remote_ip, system.login, base_product.id, is_byos: system.proxy_byos)
    is_valid
  rescue InstanceVerification::Exception => e
    message = ''
    if system.proxy_byos
      result = SccProxy.scc_check_subscription_expiration(request.headers, system.login, system.system_token, logger)
      if result[:is_active]
        InstanceVerification.update_cache(request.remote_ip, system.login, base_product.id, is_byos: system.proxy_byos)
        return true
      end

      message = result[:message]
    else
      message = e.message
    end
    details = [ "System login: #{system.login}", "IP: #{request.remote_ip}" ]
    details << "Instance ID: #{verification_provider.instance_id}" if verification_provider.instance_id
    details << "Billing info: #{verification_provider.instance_billing_info}" if verification_provider.instance_billing_info

    ZypperAuth.auth_logger.info <<~LOGMSG
    Access to the repos denied: #{message}
      #{details.join(', ')}
    LOGMSG
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

        def verify_product_activation
          product = find_product

          if product.base?
            verify_base_product_activation(product)
          else
            verify_extension_activation(product)
          end
        rescue InstanceVerification::Exception => e
          unless @system.proxy_byos
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

        def verify_extension_activation(product)
          return if product.free?

          base_product = @system.products.find_by(product_type: :base)

          subscription = Subscription.joins(:product_classes).find_by(
            subscription_product_classes: {
              product_class: base_product.product_class
            }
          )

          # This error would occur only if there's a problem with subscription setup on SCC side
          raise "Can't find a subscription for base product #{base_product.product_string}" unless subscription

          allowed_product_classes = subscription.product_classes.pluck(:product_class)

          unless allowed_product_classes.include?(product.product_class)
            raise InstanceVerification::Exception.new(
              'The product is not available for this instance'
            )
          end
        end

        def verify_base_product_activation(product)
          verification_provider = InstanceVerification.provider.new(
            logger,
            request,
            params.permit(:identifier, :version, :arch, :release_type).to_h,
            @system.instance_data
          )

          raise 'Unspecified error' unless verification_provider.instance_valid?
          InstanceVerification.update_cache(request.remote_ip, @system.login, product.id, is_byos: @system.proxy_byos)
        end

        # Verify that the base product doesn't change in the offline migration
        def verify_base_product_upgrade
          upgrade_product = find_product
          return unless upgrade_product.base?

          activated_bases = @system.products.where(product_type: 'base')
          activated_bases.each do |base_product|
            return true if (base_product.identifier == upgrade_product.identifier)
          end

          raise ActionController::TranslatedError.new('Migration target not allowed on this instance type')
        end
      end
    end
  end
end
