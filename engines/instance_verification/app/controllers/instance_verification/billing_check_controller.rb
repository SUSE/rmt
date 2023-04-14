module InstanceVerification
  class BillingCheckController < ::ApplicationController
    def check
      # return a string indicating if the instance metadata
      # belongs to a PAYG or BYOS instance
      metadata = verification.parse_instance_data(params[:metadata])
      is_payg = verification_provider.payg_billing_code?(
        metadata[:billingProducts]&.first,
        metadata[:marketplaceProductCodes]&.first,
        params[:identifier]
      )

      product_billing = 'BYOS'
      product_billing = 'PAYG' if is_payg

      render status: 200, json: { state: product_billing }
     end
  end
end
