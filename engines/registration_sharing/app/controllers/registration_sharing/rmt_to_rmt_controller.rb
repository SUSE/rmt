require_dependency 'registration_sharing/application_controller'

module RegistrationSharing
  class RmtToRmtController < ApplicationController

    # InnoDB resolves a lock cycle by rolling one transaction back whole, so the
    # retry has to wrap the transaction from the outside: by the time the error
    # reaches us the locks are already released and there is nothing left to
    # rescue from within
    DEADLOCK_RETRIES = 3

    before_action :authenticate

    def create
      attempts = 0
      begin
        attempts += 1
        create_or_update_system
      rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout => e
        raise if attempts >= DEADLOCK_RETRIES

        Rails.logger.warn(
          "regsharing: #{e.class} for login #{params[:login]}, attempt #{attempts}/#{DEADLOCK_RETRIES}, retrying"
        )
        # jittered so two transactions that just collided do not line up again
        sleep(rand(0.02..0.1) * attempts)
        retry
      end
    end

    def destroy
      system = System.find_by(login: params[:login])
      system.destroy if system
    end

    protected

    def fetch_system
      credentials = {
        login: params[:login],
        password: params[:password],
        system_token: params[:system_token]
      }
      System.find_or_create_by(credentials)
    rescue ActiveRecord::RecordNotUnique
      System.find_by!(credentials)
    end

    def create_or_update_system
      # read_committed because under repeatable read the activations delete
      # takes next-key locks covering the gaps a concurrent push then has to
      # insert into; read_committed takes record locks only
      System.transaction(isolation: :read_committed) do
        system = fetch_system
        system.lock!
        system.assign_attributes(system_params)
        system.save! # save the system early, if it fails, no activations handled

        sync_activations(system)
      end
    end

    def sync_activations(system)
      activations = params[:activations] || []
      product_ids = activations.map { |a| a[:product_id].to_i }.uniq
      # batch load all products and services
      # prevent a second hidden (N+1) query when the loop calls product.service on every iteration
      # it eager-loads the services alongside the products
      products_by_id = Product.includes(:service).where(id: product_ids).index_by(&:id)

      wanted = activations.to_h do |activation|
        product_id = activation[:product_id].to_i
        product = products_by_id[product_id]
        raise "Product #{product_id} not found" unless product

        [product.service.id, activation[:created_at]]
      end

      existing_ids = system.activations.pluck(:service_id)
      removed = existing_ids - wanted.keys
      system.activations.where(service_id: removed).delete_all if removed.any?

      (wanted.keys - existing_ids).each do |service_id|
        system.activations.create!(
          service_id: service_id,
          created_at: wanted[service_id]
        )
      end
    end

    def system_params
      params.permit(
        :login, :password, :hostname, :proxy_byos_mode,
        :system_token, :registered_at, :created_at, :last_seen_at,
        :instance_data, :pubcloud_reg_code
      )
    end

    def authenticate
      authenticate_or_request_with_http_token do |token, _options|
        secret = RegistrationSharing.config_api_secret
        return false unless secret

        ActiveSupport::SecurityUtils.secure_compare(token, secret)
      end
    end
  end
end
