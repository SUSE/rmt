RegistrationSharing::Engine.routes.draw do
  # /center/regsvc?command=shareregistration&lang=en-US&version=1.0
  post 'center/regsvc', to: 'smt_to_rmt#regsvc'
end
