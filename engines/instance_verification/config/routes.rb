InstanceVerification::Engine.routes.draw do
  get 'check', to: 'billing_check#check'
end
