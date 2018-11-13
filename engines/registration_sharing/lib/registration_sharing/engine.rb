module RegistrationSharing
  class Engine < ::Rails::Engine
    isolate_namespace RegistrationSharing
    config.generators.api_only = true

    config.generators do |g|
      g.test_framework :rspec
    end

    config.after_initialize do
      System.class_eval do
        after_commit :share_registration

        def share_registration
          return if self.class == RegistrationSharing::System
          RegistrationSharing.share(self)
        end
      end

      Activation.class_eval do
        after_commit :share_registration

        def share_registration
          return if self.class == RegistrationSharing::Activation
          RegistrationSharing.share(self)
        end
      end
    end
  end
end
