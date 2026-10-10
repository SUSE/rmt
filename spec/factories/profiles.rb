FactoryBot.define do
  factory :profile do
    sequence(:profile_type) { |n| "ptype_#{n}" }
    sequence(:identifier) { |n| "ident_#{n}" }
    sequence(:data) { |n| { test_key: 'test_value', count: n } }
  end
end
