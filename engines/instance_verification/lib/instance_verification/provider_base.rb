class InstanceVerification::ProviderBase
  def self.inherited(child_class)
    InstanceVerification.provider = child_class
  end

  def initialize(logger, request, product_hash, instance_data, debug = false)
    @logger = logger
    @request = request
    @product_hash = product_hash
    @instance_data = instance_data
    @instance_id = nil # set by CSP-specific implementation, used for logging errors
    @instance_billing_info = nil # set by CSP-specific implementation, used for logging errors
    @debug = debug
  end

  attr_reader(:instance_id, :instance_billing_info)
end
