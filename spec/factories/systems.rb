FactoryGirl.define do
  factory :system do
    sequence(:login) { |n| "login#{n}" }
    sequence(:password) { |n| "password#{n}" }

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
  end
end
