FactoryGirl.define do
  factory :system do
    sequence(:login) { |n| "login#{n}" }
    sequence(:password) { |n| "password#{n}" }

    trait :with_activated_base_product do
      after :create do |system, _|
        create(:activation, system: system, service: create(:service)) if system.services.blank?
      end
    end
  end
end
