module Registry
  class Engine < ::Rails::Engine
    isolate_namespace Registry
    config.generators.api_only = true
  end
end
