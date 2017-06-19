class ProductsRepositoriesAssociation < ApplicationRecord

  self.table_name = 'products_repositories'

  belongs_to :product
  belongs_to :repository

end
