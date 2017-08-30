FactoryGirl.define do
  factory :subscription do
    sequence(:regcode) { |n| n.to_s.ljust(13, 'A') }
    sequence(:name) { |n| "Subscription #{n}" }
    status 'ACTIVE'
    kind 'full'
    sequence(:system_limit) { Random.rand(15) + 2 }
    sequence(:starts_at) { Time.zone.now }
    sequence(:expires_at) { Time.zone.now + 1.year }
    sequence(:systems_count) { Random.rand(1) }

    trait :expired do
      expires_at Time.zone.now - 2.days
    end

    transient do
      product_classes nil
    end

    after :create do |subscription, evaluator|
      if evaluator.product_classes
        evaluator.product_classes.each do |product_class|
          FactoryGirl.create(:subscription_product_class, product_class: product_class, subscription_id: subscription.id)
        end
      end
    end

    trait :with_products do
      after :create do |subscription, _evaluator|
        2.times do
          product_class = FactoryGirl.create(:subscription_product_class, subscription_id: subscription.id)
          FactoryGirl.create(:product, :with_mirrored_repositories, product_class: product_class.product_class)
        end
      end
    end
  end
end
