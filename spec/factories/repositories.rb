FactoryGirl.define do
  factory :repository do
    sequence(:scc_id) { |n| n }
    sequence(:name) { |n| "Repository #{n}" }
    sequence(:external_url) { |n| "https://updates.suse.com/suse/repository_#{n}" }
    enabled true
    autorefresh true
    mirroring_enabled false
    installer_updates false

    after(:build) do |obj|
      obj.local_path = Repository.make_local_path(obj.external_url)
    end

    trait :authenticated do
      sequence(:url) { "/#{FFaker.letterify('?????')}" }
    end

    trait :custom do
      scc_id nil
    end

    trait :with_products do
      transient do
        products_count 1
      end

      after :create do |repository, evaluator|
        evaluator.products_count.times do
          repository.services << create(:service)
        end
      end
    end
  end
end
