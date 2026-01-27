FactoryBot.define do
  factory :system_profile do
    # init join table, creating entries as needed
    system
    profile
  end
end
