module InstanceVerification::Providers
  class Example
    InstanceVerification.provider = self

    def self.instance_valid?(_request, _product_hash, _instance_data)
      true # this is an example, always returns true
    end
  end
end
