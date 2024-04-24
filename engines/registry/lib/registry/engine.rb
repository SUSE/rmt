require 'fileutils'

module Registry
  class Engine < ::Rails::Engine
    isolate_namespace Registry
    config.generators.api_only = true

    config.after_initialize do
      Api::Connect::V3::Systems::ActivationsController.class_eval do
        before_action :handle_cache, only: %w[index]

        def handle_cache
          # get request header
          if request.headers['X-Refresh-Registry-Creds'] && ZypperAuth.verify_instance(request, logger, @system)
            # create cache directory
            registry_cache_dir_path = Rails.root.join('tmp/registry/cache')
            FileUtils.mkdir_p(registry_cache_dir_path)

            # update cache if expired
            # if file exists and exists longer than the cache expiration time
            # it needs to be updated
            cache_key = [request.remote_ip, @system.login].join('-')
            registry_cache_path = File.join(registry_cache_dir_path, cache_key)
            expiration_value = Settings[:registry].try(:token_expiration) || 8.hours.to_i
            cache_is_valid = File.exist?(registry_cache_path) && File.ctime(registry_cache_path) > expiration_value.seconds.ago
            FileUtils.touch(registry_cache_path) unless cache_is_valid
          end
        end
      end
    end
  end
end
