FactoryBot.define do
  factory :profile do
    sequence(:profile_type) { |n| "ptype_#{n}" }
    sequence(:identifier) { |n| "ident_#{n}" }
    sequence(:data) { |n| "data_#{n}" }
  end
end
