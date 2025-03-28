require 'base64'
require 'fileutils'

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

  def self.build_cache_entry(remote_ip, system_login, encoded_reg_code, mode, product)
    if mode == 'payg'
      [remote_ip, system_login, product.id].join('-')
    elsif mode == 'registry'
      [remote_ip, system_login].join('-')
    else
      # for byos or hybrid cache
      product_hash = product.attributes.symbolize_keys.slice(:identifier, :version, :arch)
      product_triplet = "#{product_hash[:identifier]}_#{product_hash[:version]}_#{product_hash[:arch]}"
      "#{encoded_reg_code}-#{product_triplet}"
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
    File.unlink(full_path_cache_key) if File.exist?(full_path_cache_key)
  end

  def self.set_cache_inactive(cache_key, mode)
    InstanceVerification.remove_entry_from_cache("#{cache_key}-active", mode)
    cache_key = [cache_key, 'inactive'].join('-')
    InstanceVerification.update_cache(cache_key, mode)
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
          add_on_product_class = InstanceVerification.provider.new(
            logger,
            request,
            product_hash,
            @system.instance_data
          ).add_on
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
          logger.info "Product #{@product.product_string} available for this instance"
          cache_key = InstanceVerification.build_cache_entry(request.remote_ip, @system.login, nil, 'payg', product)
          InstanceVerification.update_cache(cache_key, 'payg')
        end

        def verify_base_product_activation(product)
          verification_provider = InstanceVerification.provider.new(
            logger,
            request,
            params.permit(:identifier, :version, :arch, :release_type).to_h,
            @system.instance_data
          )
          raise 'Unspecified error' unless verification_provider.instance_valid?

          encoded_reg_code = @system.pubcloud_reg_code
          # we use the token sent from the client if present
          # instead of the value stored in the DB
          encoded_reg_code = Base64.strict_encode64(params[:token]) if params[:token].present?

          cache_key = InstanceVerification.build_cache_entry(
            request.remote_ip, @system.login, encoded_reg_code, @system.proxy_byos_mode, product
          )
          InstanceVerification.update_cache("#{cache_key}-active", @system.proxy_byos_mode)
        end

        # Verify that the base product doesn't change in the offline migration
        def verify_base_product_upgrade
          upgrade_product = find_product
          return unless upgrade_product.base?

          activated_bases = @system.products.where(product_type: 'base')
          activated_bases.each do |base_product|
            base_product_subscription = find_subscription(base_product, logger, request)
            return true if base_product_subscription && base_product_subscription.products.include?(upgrade_product)
          end

          raise ActionController::TranslatedError.new('Migration target not allowed on this instance type')
        end
      end
    end
  end
end
