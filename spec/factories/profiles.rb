FactoryBot.define do
  factory :profile do
    sequence(:profile_type) { |n| "ptype_#{n}" }
    sequence(:identifier) { |n| "ident_#{n}" }
    data { { 'test_key' => 'test_value' } }
  end
end
