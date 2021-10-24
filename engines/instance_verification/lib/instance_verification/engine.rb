require 'net/http'

ACTIVATE_PRODUCT_URL = 'https://scc.suse.com/connect/systems/products'

module InstanceVerification
  class << self
    include ::Net::HTTPHeader

    def verification_basic_encode(login, password)
      basic_encode(login, password)
    end
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
          @system.hw_info.instance_data = params[:instance_data]
          @system.hw_info.save!
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
          # check BYOS instances with SCC
          unless params[:token] && scc_activate_product
            raise ActionController::TranslatedError.new('Instance verification failed: %{message}' % { message: e.message })
          end
          update_subscription
          update_cache(product.id)
        rescue StandardError => e
          logger.error('Unexpected instance verification error has occurred:')
          logger.error(e.message)
          logger.error("System login: #{@system.login}, IP: #{request.remote_ip}")
          logger.error('Backtrace:')
          logger.error(e.backtrace)
          raise ActionController::TranslatedError.new('Unexpected instance verification error has occurred')
        end

        def update_cache(product_id)
          cache_key = [request.remote_ip, @system.login, product_id].join('-')
          # caches verification result to be used by zypper auth plugin
          Rails.cache.write(cache_key, true, expires_in: 20.minutes)
        end

        def prepare_scc_request(uri_path, method=nil)
          basic_encode_scc = 'Basic ' + ["#{@system.login}:#{@system.password}"].pack('m').delete("\r\n")
          activate_header = {
            'accept': 'application/json,application/vnd.scc.suse.com.v4+json',
            'Content-Type': 'application/json',
            'Authorization': InstanceVerification.verification_basic_encode(@system.login, @system.password)
          }
          unless method
            scc_request = Net::HTTP::Post.new(uri_path, activate_header) unless method
            email = params[:email] ? params[:email] : nil
            scc_request.body = {
              token: params[:token],
              identifier: params[:identifier],
              version: params[:version],
              arch: params[:arch],
              release_type: params[:release_type],
              email: nil
            }.to_json
            return scc_request
          end
          Net::HTTP::Get.new(uri_path, activate_header)
        end

        def scc_activate_product
          uri = URI.parse(ACTIVATE_PRODUCT_URL)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          scc_request = prepare_scc_request(uri.path)
          response = http.request(scc_request)
          prod = [
            params[:identifier], params[:version], params[:arch]
          ].join('-')
          logger.info(
            "Response code #{response.code} for the attempt to " \
            "activate product #{prod} to SCC"
          )
          return false unless response.code_type == Net::HTTPCreated

          logger.info "Product #{prod} successfully activated"
          true
        end

        def update_subscription
          uri = URI.parse(SYSTEM_SUBSCRIPTION_URL)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          scc_request = prepare_scc_request(uri.path, 'get')
          response = http.request(scc_request)

          return false unless response.code_type == Net::HTTPOK

          parsed_response = JSON.parse(response.body)[0]
          subscription = Subscription.find_or_create_by(id: parsed_response['id'].to_i)
          subscription.attributes = parsed_response.select { |k, _| subscription.attributes.keys.member?(k.to_s) }
          subscription.kind = parsed_response['type']
          subscription.save!

          parsed_response['product_classes'].each do |product_class|
            SubscriptionProductClass.find_or_create_by(subscription_id: subscription.id, product_class: product_class)
          end
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
            @system.hw_info&.instance_data
          )

          raise 'Unspecified error' unless verification_provider.instance_valid?

          update_cache(product.id)
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
