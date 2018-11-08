class Product < ApplicationRecord

  has_one :service, dependent: :destroy
  has_many :repositories, through: :service

  has_many :product_extensions_associations,
           class_name: 'ProductsExtensionsAssociation',
           foreign_key: :extension_id

  has_many :bases,
           through: :product_extensions_associations,
           source: :product

  # Product extensions - get list of product extensions
  has_many :extension_products_associations,
           class_name: 'ProductsExtensionsAssociation',
           foreign_key: :product_id

  has_many :extensions, -> { distinct },
    through: :extension_products_associations,
    source: :extension do
    def for_root_product(root_product)
      where('products_extensions.root_product_id = %s', root_product.id)
    end
  end

  has_many :mirrored_extensions, -> { mirrored },
    through: :extension_products_associations,
    source: :extension do
    def for_root_product(root_product)
      where('products_extensions.root_product_id = %s', root_product.id)
    end
  end

  has_and_belongs_to_many :predecessors, class_name: 'Product', join_table: :product_predecessors,
    association_foreign_key: :predecessor_id

  has_and_belongs_to_many :successors, class_name: 'Product', join_table: :product_predecessors,
    association_foreign_key: :product_id, foreign_key: :predecessor_id

  enum product_type: { base: 'base', module: 'module', extension: 'extension' }

  scope :free, -> { where(free: true) }
  scope :mirrored, lambda {
    distinct.joins(:repositories).where('repositories.enabled = true').group(:id).having('count(*)=count(CASE WHEN mirroring_enabled THEN 1 END)')
  }

  scope :with_release_stage, lambda { |release_stage|
    if release_stage
      where(release_stage: release_stage)
    else
      all
    end
  }

  def has_extension?
    ProductsExtensionsAssociation.exists?(product_id: id)
  end

  def mirror?
    repositories.where(enabled: true, mirroring_enabled: false).empty?
  end

  def last_mirrored_at
    repositories.where(mirroring_enabled: true).maximum(:last_mirrored_at)
  end

  def self.clean_up_version(version)
    return unless version
    [version, version.tr('-', '.').chomp('.0')].uniq
  end

  def product_string
    [identifier, version, arch].join('/')
  end

  def change_repositories_mirroring!(conditions, mirroring_enabled)
    repositories.where(conditions).update_all(mirroring_enabled: mirroring_enabled)
  end

  def recommended_for?(root_product)
    product_extensions_associations.where(recommended: true).where(root_product: root_product).present?
  end

  def available_for
    product_extensions_associations.includes(:root_product).map(&:root_product).uniq
  end

  def self.available_or_recommended_modules(root_product_ids)
    joins(:product_extensions_associations).free.module.where(products_extensions: { root_product_id: root_product_ids }).or(
      recommended_extensions(root_product_ids)
    ).distinct
  end

  def self.free_and_recommended_modules(root_product_ids)
    joins(:product_extensions_associations).free
        .where(products_extensions: { root_product_id: root_product_ids })
        .or(recommended_extensions(root_product_ids))
        .distinct
  end

  def self.recommended_extensions(root_product_ids)
    joins(:product_extensions_associations).where(products_extensions: { recommended: true, root_product_id: root_product_ids })
  end

  def service
    Service.find_or_create_by(product_id: id)
  end

end
