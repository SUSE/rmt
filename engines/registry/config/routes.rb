Registry::Engine.routes.draw do
  get 'authorize', to: 'registry#authorize'
  get 'catalog', to: 'registry#catalog'
end
