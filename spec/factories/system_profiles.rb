FactoryBot.define do
  factory :system_profile do
    # initialize join table, creating entries as needed
    system
    system_data_profile
  end
end
