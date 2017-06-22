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

  enum product_type: { base: 'base', module: 'module', extension: 'extension' }

end
