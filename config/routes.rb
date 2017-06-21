Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  namespace :connect, module: 'api/connect', defaults: { format: 'json' } do
    api_version(module: 'V4', header: { name: 'Accept', value: 'application/vnd.scc.suse.com.v4+json' }, default: true) do
      scope :subscriptions, module: :subscriptions do
        post 'systems', to: 'systems#announce_system'
      end

      scope :systems, module: :systems, as: 'systems' do
        post 'products', to: 'products#activate'
      end
    end
  end

  get 'services/:id', to: 'services#show', as: :service
  get 'services/:id/repo/repoindex.xml', to: 'services#show'
end
