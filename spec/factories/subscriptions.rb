FactoryGirl.define do
  factory :subscription do
    sequence(:regcode) { |n| n.to_s.ljust(13, 'A') }
    sequence(:name) { |n| "Subscription #{n}" }
    sequence(:status) { 'ACTIVE' }
    sequence(:kind) { 'full' }
    sequence(:system_limit) { Random.rand(15) + 2 }
    sequence(:starts_at) { Time.zone.now }
    sequence(:expires_at) { Time.zone.now + 1.year }
    sequence(:systems_count) { Random.rand(1) }

    trait :expired do
      expires_at Time.zone.now - 2.days
    end
  end
end
