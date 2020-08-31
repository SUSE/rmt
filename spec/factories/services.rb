FactoryGirl.define do
  factory :service do
    association :product

    trait :with_repositories do
      transient do
        mirroring_enabled false
      end

      after :create do |service, evaluator|
        name_prefix = service.product.name
        last_mirrored_at = evaluator.mirroring_enabled ? Time.zone.now : nil

        service.repositories << [
          FactoryGirl.create(:repository, name: "#{name_prefix}-Pool", mirroring_enabled: evaluator.mirroring_enabled, last_mirrored_at: last_mirrored_at),
          FactoryGirl.create(:repository, name: "#{name_prefix}-Updates", mirroring_enabled: evaluator.mirroring_enabled, last_mirrored_at: last_mirrored_at),
          FactoryGirl.create(
            :repository,
            name: "#{name_prefix}-Installer-Updates",
            mirroring_enabled: evaluator.mirroring_enabled,
            last_mirrored_at: last_mirrored_at,
            installer_updates: true,
            enabled: false
          ),
          FactoryGirl.create(
            :repository,
            name: "#{name_prefix}-Debuginfo-Updates",
            mirroring_enabled: evaluator.mirroring_enabled,
            last_mirrored_at: last_mirrored_at,
            installer_updates: false,
            enabled: false
          )
        ]
      end
    end

    trait :with_disabled_repositories do
      transient do
        mirroring_enabled false
      end

      after :create do |service, evaluator|
        name_prefix = service.product.name
        last_mirrored_at = evaluator.mirroring_enabled ? Time.zone.now : nil

        service.repositories << [
          FactoryGirl.create(
            :repository,
            name: "#{name_prefix}-Installer-Updates",
            mirroring_enabled: evaluator.mirroring_enabled,
            last_mirrored_at: last_mirrored_at,
            installer_updates: true,
            enabled: false
          ),
          FactoryGirl.create(
            :repository,
            name: "#{name_prefix}-Debuginfo-Updates",
            mirroring_enabled: evaluator.mirroring_enabled,
            last_mirrored_at: last_mirrored_at,
            installer_updates: false,
            enabled: false
          )
        ]
      end
    end
  end
end
