FactoryGirl.define do
  factory :activation do
    association :system
    association :service, factory: %i[service with_repositories]

    factory :activation_free_product do
      after :build do |activation, _evaluator|
        activation.service.product.update_attribute(:free, true)
      end
    end

    trait :with_mirrored_product do
      after :build do |activation, _evaluator|
        activation.service.product.repositories.update_all(mirroring_enabled: true)
      end
    end
  end
end
