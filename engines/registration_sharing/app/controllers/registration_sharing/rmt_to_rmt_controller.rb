require_dependency 'registration_sharing/application_controller'

module RegistrationSharing
  class RmtToRmtController < ApplicationController

    before_action :authenticate

    def create
      System.transaction do
        system = System.find_or_create_by(login: params[:login])
        system.update(system_params)

        system.activations = []
        params[:activations].each do |activation|
          product = Product.find_by(id: activation[:product_id])
          raise "Product #{product_id} not found" unless product

          system.activations << Activation.new(
            service: product.service,
            created_at: activation[:created_at]
          )
        end

        system.hw_info ||= HwInfo.create
        system.hw_info.instance_data = params[:instance_data]
        system.hw_info.save!

        system.save!
      end
    end

    def destroy
      system = System.find_by(login: params[:login])
      system.destroy if system
    end

    protected

    def system_params
      params.permit(:login, :password, :hostname, :registered_at, :created_at, :last_seen_at)
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
