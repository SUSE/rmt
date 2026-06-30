require_dependency 'registration_sharing/application_controller'

module RegistrationSharing
  class RmtToRmtController < ApplicationController

    before_action :authenticate

    def create
      System.transaction do
        system = System.find_or_create_by(
          login: params[:login],
          password: params[:password],
          system_token: params[:system_token]
        )
        system.update(system_params)

        system.activations = []
        product_ids = params[:activations].map { |a| a[:product_id].to_i }.uniq
        # batch load all products and services
        # prevent a second hidden (N+1) query when the loop calls product.service on every iteration
        # it eager-loads the services alongside the products
        products_by_id = Product.includes(:service).where(id: product_ids).index_by(&:id)

        params[:activations].each do |activation|
          product = products_by_id[activation[:product_id].to_i]
          raise "Product #{product_id} not found" unless product

          system.activations << Activation.new(
            service: product.service,
            created_at: activation[:created_at]
          )
        end

        system.instance_data = params[:instance_data]
        system.save!
      end
    end

    def destroy
      system = System.find_by(login: params[:login])
      system.destroy if system
    end

    protected

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
