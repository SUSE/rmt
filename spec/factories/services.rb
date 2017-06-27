FactoryGirl.define do
  factory :service do
    association :product

    trait :with_repositories do
      after :create do |service|
        name_prefix = service.product.name

        service.repositories << [
          FactoryGirl.create(:repository, name: "#{name_prefix}-Base"),
          FactoryGirl.create(:repository, name: "#{name_prefix}-Pool"),
          FactoryGirl.create(:repository, name: "#{name_prefix}-Updates"),
          FactoryGirl.create(:repository, name: "#{name_prefix}-SDK")
        ]
      end
    end
  end
end
