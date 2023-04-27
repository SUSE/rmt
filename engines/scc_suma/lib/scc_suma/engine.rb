module SccSuma
  class Engine < ::Rails::Engine
    isolate_namespace SccSuma
    config.generators.api_only = true

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
