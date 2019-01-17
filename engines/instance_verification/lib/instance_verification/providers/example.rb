class InstanceVerification::Providers::Example < InstanceVerification::ProviderBase
  def instance_valid?
    true # this is an example, always returns true
  end
end
