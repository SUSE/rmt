class InstanceVerification::Providers::Example < InstanceVerification::ProviderBase
  def instance_valid?
    @instance_id = 'i-0000000000'
    @instance_billing_info = 'example'
    true # this is an example, always returns true
  end
end
