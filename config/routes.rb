Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  namespace :connect, module: 'api/connect', defaults: { format: 'json' } do
    api_version(module: 'V4', header: { name: 'Accept', value: 'application/vnd.scc.suse.com.v4+json' }, default: true) do
      scope :subscriptions, module: :subscriptions do
        post 'systems', to: 'systems#announce_system'
        resources :products, only: [:index]
      end

      put 'systems', to: 'systems/systems#update'
      delete 'systems', to: 'systems/systems#deregister'

      scope :systems, module: :systems, as: 'systems' do
        get 'products', to: 'products#show'
        post 'products', to: 'products#activate'
        put 'products', to: 'products#upgrade'
        delete 'products', to: 'products#destroy'
        post 'products/migrations', to: 'products#migrations'
        post 'products/offline_migrations', to: 'products#offline_migrations'
        post 'products/synchronize', to: 'products#synchronize'
      end

      resource :systems, only: [], module: :systems do
        resources :activations, only: [ :index ]
      end

      get 'repositories/installer', to: 'repositories/installer#index'
    end
  end

  namespace :connect, module: 'api/connect', defaults: { format: 'json' } do
    api_version(module: 'V3', header: { name: 'Accept', value: 'application/vnd.scc.suse.com.v3+json' }) do
      scope :subscriptions, module: :subscriptions do
        post 'systems', to: 'systems#announce_system'
      end

      put 'systems', to: 'systems/systems#update'
      delete 'systems', to: 'systems/systems#deregister'

      scope :systems, module: :systems, as: 'systems' do
        get 'products', to: 'products#show'
        post 'products', to: 'products#activate'
        put 'products', to: 'products#upgrade'
        post 'products/migrations', to: 'products#migrations'
        post 'products/offline_migrations', to: 'products#offline_migrations'
      end

      resource :systems, only: [], module: :systems do
        resources :activations, only: [ :index ]
      end
    end
  end

  get 'services/:id', to: 'services#show', as: :service
  get 'services/:id/repo/repoindex.xml', to: 'services#show'
  get '/repo/repoindex.xml', to: 'services#legacy_service'

  get '/api/health/status', to: 'api/health#status'

  mount StrictAuthentication::Engine, at: '/api/auth' if defined?(StrictAuthentication::Engine)
  mount RegistrationSharing::Engine, at: '/api/regsharing' if defined?(RegistrationSharing::Engine)
end
