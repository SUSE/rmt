require_dependency 'registration_sharing/application_controller'

module RegistrationSharing
  class RmtToRmtController < ApplicationController

    def create
      System.transaction do
        system = RegistrationSharing::System.find_or_create_by(login: params[:login])

        %w[password hostname registered_at last_seen_at].each do |attribute|
          system.send("#{attribute}=", params[attribute])
        end

        system.activations = []
        params[:activations].each do |activation|
          product = Product.find_by(id: activation[:product_id])
          raise "Product #{product_id} not found" unless product

          system.activations << RegistrationSharing::Activation.new(
            service: product.service,
            created_at: activation[:created_at]
          )
        end

        system.save!
      end
    end

    def delete
      system = RegistrationSharing::System.find_by(login: params[:login])
      system.destroy if system
    end
  end
end
