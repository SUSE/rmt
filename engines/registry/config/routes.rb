Registry::Engine.routes.draw do
  get 'authorize', to: 'registry#authorize'
end
