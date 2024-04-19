require 'fileutils'

module Registry
  class Engine < ::Rails::Engine
    isolate_namespace Registry
    config.generators.api_only = true

    # REGISTRY_CACHE_PATH = Rails.root.join('tmp', 'registry', 'cache')

    config.after_initialize do
      Api::Connect::V3::Systems::ActivationsController.class_eval do

        before_action :handle_cache, only: %w[index]

        def handle_cache
          # get request header
          if request.headers['X-Registry']
            registry_cache_path = Rails.root.join('tmp', 'registry', 'cache')
            Dir.mkdir(registry_cache_path) unless Dir.exist?(registry_cache_path)

            cache_key = [request.remote_ip, @system.login].join('-')
            FileUtils.touch File.join(registry_cache_path, cache_key)
          end
        end
      end
    end
  end
end
