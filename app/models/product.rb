class Product < ApplicationRecord

  has_one :service
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

  has_many :extensions,
           through: :extension_products_associations,
           source: :extension

  has_many :mirrored_extensions, -> { mirrored },
    through: :extension_products_associations,
    source: :extension

  has_and_belongs_to_many :predecessors, class_name: 'Product', join_table: :product_predecessors,
    association_foreign_key: :predecessor_id

  has_and_belongs_to_many :successors, class_name: 'Product', join_table: :product_predecessors,
    association_foreign_key: :product_id, foreign_key: :predecessor_id

  enum product_type: { base: 'base', module: 'module', extension: 'extension' }

  scope :mirrored, lambda {
    distinct.joins(:repositories).where('repositories.enabled = true').group(:id).having('count(*)=count(CASE WHEN mirroring_enabled THEN 1 END)')
  }

  scope :published, ->() { where(release_stage: 'released') }

  def has_extension?
    ProductsExtensionsAssociation.exists?(product_id: id)
  end

  def is_mirrored
    repositories.where(enabled: true, mirroring_enabled: false).empty?
  end

  def self.clean_up_version(version)
    return unless version
    version.tr('-', '.').chomp('.0')
  end

end
