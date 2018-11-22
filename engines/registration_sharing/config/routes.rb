RegistrationSharing::Engine.routes.draw do
  post 'center/regsvc', to: 'smt_to_rmt#regsvc'
  post '/', to: 'rmt_to_rmt#create'
  delete '/', to: 'rmt_to_rmt#destroy'
end
