require 'fileutils'

module InstanceVerification
  def self.update_cache(remote_ip, system_login, product_id, registry: false)
    # TODO: BYOS scenario
    # to be addressed on a different PR
    unless registry
      InstanceVerification.write_cache_file(
        Rails.application.config.repo_cache_dir,
        [remote_ip, system_login, product_id].join('-')
      )
    end

    InstanceVerification.write_cache_file(
      Rails.application.config.registry_cache_dir,
      [remote_ip, system_login].join('-')
    )
  end

  def self.write_cache_file(cache_dir, cache_key)
    FileUtils.mkdir_p(cache_dir)
    FileUtils.touch(File.join(cache_dir, cache_key))
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
          # i.e. in the case of SUMA, it would SUMA product class
          # not the SUMA base product class (Micro)
          product_class = add_on_product_class.presence || base_product.product_class
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
          InstanceVerification.update_cache(request.remote_ip, @system.login, product.id)
        end

        def verify_base_product_activation(product)
          verification_provider = InstanceVerification.provider.new(
            logger,
            request,
            params.permit(:identifier, :version, :arch, :release_type).to_h,
            @system.instance_data
          )

          raise 'Unspecified error' unless verification_provider.instance_valid?
          InstanceVerification.update_cache(request.remote_ip, @system.login, product.id)
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
