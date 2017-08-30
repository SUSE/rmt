FactoryGirl.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:identifier) { |n| "product-#{n}" }
    sequence(:cpe) { |n| "cpe:/o:product:#{n}" }
    sequence(:shortname) { |n| "Product #{n}" }
    sequence(:friendly_name) { |n| "Product #{n}" }
    sequence(:product_class) { |n| n.to_s.ljust(5, 'A') }
    free false
    product_type :base
    sequence(:description) { FFaker::Lorem.sentence }
    release_type ''
    version 42
    arch 'x86_64'

    transient do
      base_products []
      predecessor nil
    end

    after :create do |product, evaluator|
      evaluator.base_products.each do |base_product|
        product.product_extensions_associations << ProductsExtensionsAssociation.create(product: base_product)
      end

      product.predecessors << evaluator.predecessor if evaluator.predecessor
    end

    trait :extension do
      product_type 'extension'
    end

    trait :module do
      product_type 'module'
    end

    trait :with_extensions do
      after :create do |product, _evaluator|
        5.times do
          extension = create :product, :extension
          product.extensions << extension
        end
      end
    end

    trait :with_modules do
      after :create do |product, _evaluator|
        5.times do
          mod = create :module
          product.extensions << mod
        end
      end
    end

    trait :cloned do
      transient do
        from nil
      end
      after :build do |product, evaluator|
        if evaluator.from
          product.identifier = evaluator.from.identifier
          product.arch = evaluator.from.arch
          product.product_class = evaluator.from.product_class
          product.product_type = evaluator.from.product_type
        else
          fail "Trait `cloned` won't work until you provide a `from: something` parameter. And you didn't."
        end
      end
    end

    trait :with_mirrored_repositories do
      after :create do |product, _evaluator|
        unless Service.find_by(product_id: product.id)
          FactoryGirl.create(:service, :with_repositories, product: product, mirroring_enabled: true)
        end
      end
    end

    trait :with_not_mirrored_repositories do
      after :create do |product, _evaluator|
        unless Service.find_by(product_id: product.id)
          FactoryGirl.create(:service, :with_repositories, product: product, mirroring_enabled: false)
        end
      end
    end

    trait :with_packages do
      with_repositories
      after :create do |product, _evaluator|
        5.times { create :package, patch: nil, repository: product.repositories.first }
      end
    end

    trait :activated do
      transient do
        system nil
      end

      after :create do |product, evaluator|
        if evaluator.system
          unless evaluator.system.activations.map(&:product).flatten.include?(product)
            evaluator.system.activations << FactoryGirl.create(:activation, system: evaluator.system, service: product.service)
          end
        else
          fail 'activated requires a system'
        end
      end
    end
  end
end
