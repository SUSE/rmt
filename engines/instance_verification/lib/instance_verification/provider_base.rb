class InstanceVerification::ProviderBase
  def self.inherited(child_class)
    InstanceVerification.provider = child_class
  end

  def initialize(logger, request, product_hash, instance_data)
    @logger = logger
    @request = request
    @product_hash = product_hash
    @instance_data = instance_data
  end
end
