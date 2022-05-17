FactoryBot.define do
  factory :system do
    sequence(:login) { |n| "login#{n}" }
    sequence(:password) { |n| "password#{n}" }
    sequence(:hostname) { FFaker::Name.unique.first_name }

    transient do
      virtual { false }
      instance_data { nil }
    end

    trait :synced do
      sequence(:scc_system_id) { |n| n }

      after :create do |system, _|
        system.touch(:scc_synced_at)
      end
    end

    trait :byos do
      proxy_byos { true }
    end

    trait :with_activated_base_product do
      after :create do |system, _|
        create(:activation, system: system, service: create(:service)) if system.services.blank?
      end
    end

    trait :full do
      with_activated_product
      with_hw_info
      with_last_seen_at
    end

    trait :with_last_seen_at do
      last_seen_at { Time.zone.now }
    end

    trait :with_activated_product do
      transient do
        product { create(:product, :with_mirrored_repositories) }
        subscription { nil }
      end

      after :create do |system, evaluator|
        create(:activation, system: system, service: evaluator.product.service, subscription: evaluator.subscription)
      end
    end

    trait :with_hw_info do
      after :build do |system, evaluator|
        system.hw_info = FactoryBot.build(:hw_info, virtual: evaluator.virtual, instance_data: evaluator.instance_data)
      end
    end
  end
end
