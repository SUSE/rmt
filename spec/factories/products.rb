FactoryGirl.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:identifier) { |n| "product-#{n}" }
    sequence(:cpe) { |n| "cpe:/o:product:#{n}" }
    sequence(:shortname) { |n| "Product #{n}" }
    sequence(:product_class) { |n| n.to_s.ljust(5, 'A') }
    free false
    product_type :base
    sequence(:description) { FFaker::Lorem.sentence }
    release_type nil
    version 42
    arch 'x86_64'
    release_stage 'released'

    transient do
      base_products []
      root_product nil
      recommended false
      migration_kind :online
      predecessors [ ]
    end

    after :create do |product, evaluator|
      evaluator.base_products.each do |base_product|
        product.product_extensions_associations << ProductsExtensionsAssociation.create(
          product: base_product,
          root_product: evaluator.root_product || base_product,
          recommended: evaluator.recommended
        )
      end
      evaluator.predecessors.each do |predecessor|
        ProductPredecessorAssociation.create(product_id: product.id,
          predecessor_id: predecessor.id, kind: evaluator.migration_kind)
      end
    end

    trait :extension do
      product_type 'extension'
    end

    trait :module do
      product_type 'module'
      free true
    end

    trait :with_service do
      after :create do |product, _evaluator|
        product.create_service!
      end
    end

    trait :with_extensions do
      after :create do |product, _evaluator|
        5.times do
          create(:product, :extension, base_products: [product])
        end
      end
    end

    trait :with_mirrored_extensions do
      after :create do |product, _evaluator|
        5.times do
          create(:product, :extension, :with_mirrored_repositories, base_products: [product])
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

    trait :with_disabled_mirrored_repositories do
      after :create do |product, _evaluator|
        unless Service.find_by(product_id: product.id)
          FactoryGirl.create(:service, :with_disabled_repositories, product: product, mirroring_enabled: true)
        end
      end
    end

    trait :with_disabled_not_mirrored_repositories do
      after :create do |product, _evaluator|
        unless Service.find_by(product_id: product.id)
          FactoryGirl.create(:service, :with_disabled_repositories, product: product, mirroring_enabled: false)
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
