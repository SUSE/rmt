StrictAuthentication::Engine.routes.draw do
  get 'check', to: 'authentication#check'
end
