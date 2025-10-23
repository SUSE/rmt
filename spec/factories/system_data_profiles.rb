FactoryBot.define do
  factory :system_data_profile do
    sequence(:profile_type) { |n| "profType#{n}" }
    sequence(:profile_id) { |n| "profId#{n}" }
    sequence(:profile_data) { |n| "profData#{n}" }
  end
end
