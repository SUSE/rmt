FactoryGirl.define do
  factory :system do
    sequence(:login) { |n| "login#{n}" }
    sequence(:password) { |n| "password#{n}" }

    transient do
      virtual false
      instance_data nil
    end

    trait :with_activated_base_product do
      after :create do |system, _|
        create(:activation, system: system, service: create(:service)) if system.services.blank?
      end
    end

    trait :with_activated_product do
      transient do
        product { create(:product, :with_mirrored_repositories) }
      end

      after :create do |system, evaluator|
        create(:activation, system: system, service: evaluator.product.service)
      end
    end

    trait :with_hw_info do
      after :build do |system, evaluator|
        system.hw_info = FactoryGirl.build(:hw_info, virtual: evaluator.virtual, instance_data: evaluator.instance_data)
      end
    end
  end
end
