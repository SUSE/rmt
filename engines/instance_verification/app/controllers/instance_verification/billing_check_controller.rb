module InstanceVerification
  class BillingCheckController < ::ApplicationController
    def check
      # return a string indicating if the instance metadata
      # belongs to a PAYG or BYOS instance
      verification_provider = InstanceVerification.provider.new(
        logger,
        request,
        nil,
        params[:metadata]
      )

      iid = verification_provider.parse_instance_data
      is_payg = verification_provider.payg_billing_code?(iid, params[:identifier])

      render status: :ok, json: { flavor: is_payg ? 'PAYG' : 'BYOS' }
    rescue InstanceVerification::Exception => e
      logger.error "Instance metadata '#{params[:metadata]}' could not be parsed: #{e.message}"
      # when the verification failed for any reason, the agreed flavor is BYOS
      render status: :unprocessable_entity, json: { flavor: 'BYOS' }
    end
  end
end
