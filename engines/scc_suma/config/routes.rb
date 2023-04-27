SccSuma::Engine.routes.draw do
  get 'unscoped-products', to: 'scc_suma#unscoped_products'
  get 'repos', to: 'scc_suma#get_list'
  get 'subs', to: 'scc_suma#get_list'
  get 'orders', to: 'scc_suma#get_list'
  get 'product-tree', to: 'scc_suma#product_tree'
end
