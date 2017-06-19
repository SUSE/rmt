class Product < ApplicationRecord

  has_many :products_repositories_associations
  has_many :repositories, through: :products_repositories_associations

end
