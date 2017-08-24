FactoryGirl.define do
  factory :subscription_product_class do
    sequence(:subscription_id) { |n| n }
    sequence(:product_class) { (0...5).map { (65 + rand(26)).chr }.join }
  end
end
