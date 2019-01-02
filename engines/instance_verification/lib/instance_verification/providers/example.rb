module InstanceVerification::Providers
  class Example
    InstanceVerification.provider = self

    def self.verify(product_hash, instance_data)
      false
    end
  end
end