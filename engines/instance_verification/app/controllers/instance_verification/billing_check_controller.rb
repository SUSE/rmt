module InstanceVerification
  class BillingCheckController < ::ApplicationController
    def check
      # return a string indicating if the instance metadata
      # belongs to a PAYG or BYOS instance
      verification_provider = InstanceVerification.provider.new(
         nil,
         nil,
         nil,
         nil
      )

      metadata = verification_provider.parse_instance_data(params[:metadata])
      instance_billing_info = {
        billing_product: metadata['billingProducts']&.first,
        marketplace_code: metadata['marketplaceProductCodes']&.first
      }
      is_payg = verification_provider.payg_billing_code?(
        instance_billing_info,
        params[:identifier]
      )

      product_billing = 'BYOS'
      product_billing = 'PAYG' if is_payg

      render status: :ok, json: { state: product_billing }
    end
  end
end
