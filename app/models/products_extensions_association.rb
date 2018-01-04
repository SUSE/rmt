class ProductsExtensionsAssociation < ApplicationRecord

  self.table_name = 'products_extensions'
  belongs_to :product, class_name: 'Product', foreign_key: :product_id
  belongs_to :root_product, class_name: 'Product', foreign_key: :root_product_id
  belongs_to :extension, class_name: 'Product', foreign_key: :extension_id

  validates :product_id, :extension_id, :root_product_id, presence: true
  validates :product_id, uniqueness: { scope: %i[extension_id root_product_id] }

end
