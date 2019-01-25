module ZypperAuth
  class Engine < ::Rails::Engine
    isolate_namespace ZypperAuth
    config.generators.api_only = true

    config.after_initialize do
      ::V3::ServiceSerializer.class_eval do

        alias_method :original_url, :url
        def url
          original_url = original_url()
          return original_url unless @instance_options[:susecloud_plugin]

          url = URI(original_url)
          "plugin:/susecloud?credentials=#{object.name}&path=" + url.path
        end
      end

      Api::Connect::V3::Systems::ProductsController.class_eval do
        def render_service
          status = ((request.put? || request.post?) ? 201 : 200)
          # manually setting request method, so respond_with actually renders content also for PUT
          request.instance_variable_set(:@request_method, 'GET')

          instance_data = @system.hw_info&.instance_data.to_s

          respond_with(
            @product.service,
            serializer: ::V3::ServiceSerializer,
            base_url: request.base_url,
            obsoleted_service_name: @obsoleted_service_name,
            status: status,
            susecloud_plugin: instance_data.match(%r{<repoformat>plugin:susecloud</repoformat>})
          )
          end
      end

      ServicesController.class_eval do
        alias_method :original_make_repo_url, :make_repo_url

        def make_repo_url(base_url, repo_local_path, service_name)
          original_url = original_make_repo_url(base_url, repo_local_path, service_name)
          return original_url unless request.headers['X-Instance-Data']

          url = URI(original_url)
          return "plugin:/susecloud?credentials=#{service_name}&path=" + url.path
        end
      end

    end
  end
end
