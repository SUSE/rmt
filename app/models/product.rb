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

  enum product_type: { base: 'base', module: 'module', extension: 'extension' }

  scope :mirrored, lambda {
    distinct.joins(:repositories).where('repositories.enabled = true').group(:id).having('count(*)=count(CASE WHEN mirroring_enabled THEN 1 END)')
  }

  scope :published, ->() { where(release_stage: 'released') }

  def has_extension?
    ProductsExtensionsAssociation.exists?(product_id: id)
  end

  def mirrored
    return false if repositories.empty?
    repositories.all? { |r| r.enabled && r.mirroring_enabled }
  end

end
