class ProductsExtensionsAssociation < ApplicationRecord

  self.table_name = 'products_extensions'
  belongs_to :product, class_name: 'Product'
  belongs_to :root_product, class_name: 'Product'
  belongs_to :extension, class_name: 'Product'

  validates :product_id, :extension_id, :root_product_id, presence: true
  validates :product_id, uniqueness: { case_sensitive: false, scope: %i[extension_id root_product_id] }

end
