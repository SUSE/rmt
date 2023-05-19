SccSumaApi::Engine.routes.draw do
  get 'unscoped-products', to: 'scc_suma_api#unscoped_products'
  get 'repos', to: 'scc_suma_api#list'
  get 'subs', to: 'scc_suma_api#list'
  get 'orders', to: 'scc_suma_api#list'
  get 'product-tree', to: 'scc_suma_api#product_tree'
end
