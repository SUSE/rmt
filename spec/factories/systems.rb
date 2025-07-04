FactoryBot.define do
  factory :system do
    sequence(:login) { |n| "login#{n}" }
    sequence(:password) { |n| "password#{n}" }
    sequence(:hostname) { FFaker::Name.unique.first_name }

    instance_data { nil }

    transient do
      virtual { false }
    end

    trait :payg do
      proxy_byos_mode { :payg }
    end

    trait :hybrid do
      pubcloud_reg_code { 'regitration_code' }
      proxy_byos_mode { :hybrid }
    end

    trait :synced do
      sequence(:scc_system_id) { |n| n }

      after :create do |system, _|
        system.touch(:scc_synced_at)
      end
    end

    trait :byos do
      proxy_byos_mode { :byos }
    end

    trait :with_activated_base_product do
      after :create do |system, _|
        create(:activation, system: system, service: create(:service)) if system.services.blank?
      end
    end

    trait :full do
      with_activated_product
      with_system_information
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

    trait :with_activated_paid_extension do
      transient do
        product_base { create(:product, :with_mirrored_repositories, free: true) }
        paid_product { create(:product, :with_mirrored_repositories, :product_sles_ltss) }
        free_product { create(:product, :with_mirrored_repositories, free: true, product_type: :extension) }
        subscription { nil }
      end

      after :create do |system, evaluator|
        create(:activation, system: system, service: evaluator.product_base.service, subscription: evaluator.subscription)
        create(:activation, system: system, service: evaluator.paid_product.service, subscription: evaluator.subscription)
        create(:activation, system: system, service: evaluator.free_product.service, subscription: evaluator.subscription)
      end
    end

    trait :with_activated_product_sle_micro do
      transient do
        product { create(:product, :product_sle_micro, :with_mirrored_repositories) }
        subscription { nil }
      end

      after :create do |system, evaluator|
        create(:activation, system: system, service: evaluator.product.service, subscription: evaluator.subscription)
      end
    end

    trait :with_system_information do
      system_information do
        {
          cpus: 2,
          sockets: 1,
          hypervisor: nil,
          arch: 'x86_64',
          uuid: SecureRandom.uuid,
          cloud_provider: 'Amazon',
          mem_total: 64
        }.to_json
      end
    end

    trait :with_system_token do
      sequence(:system_token) { |n| "00000000-0000-4000-9000-#{n.to_s.rjust(12, '0')}" }
    end

    trait :with_system_uptimes do
      after :create do |system, _|
        create(:system_uptime, system: system)
      end
    end
  end
end
