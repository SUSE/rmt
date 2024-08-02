require_dependency 'registration_sharing/application_controller'

module RegistrationSharing
  class RmtToRmtController < ApplicationController

    before_action :authenticate

    def create
      System.transaction do
        system = System.find_or_create_by(login: params[:login])
        system.update(system_params)

        # TODO: remove this block when proxy_byos column gets dropped
        if !params.key?(:proxy_byos_mode) && system.attribute_names.include?('proxy_byos_mode')
          # the info comes from a sibling that does not have proxy_byos_mode
          # to a sibling does have proxy_byos_mode
          system.proxy_byos_mode = system.proxy_byos ? :byos : :payg
        end
        # end todo
        system.activations = []
        params[:activations].each do |activation|
          product = Product.find_by(id: activation[:product_id])
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
      params.permit(:login, :password, :hostname, :proxy_byos, :proxy_byos_mode, :system_token, :registered_at, :created_at, :last_seen_at, :instance_data)
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
