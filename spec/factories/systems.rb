FactoryGirl.define do
  factory :system do
    sequence(:login) {|n| "login#{n}" }
    sequence(:password) {|n| "password#{n}" }
  end
end
