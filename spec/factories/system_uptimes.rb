FactoryBot.define do
  factory :system_uptime do
    association :system
    sequence(:online_at_day) { Time.zone.now }
    online_at_hours { '111111111111111111111111' }
  end
end
