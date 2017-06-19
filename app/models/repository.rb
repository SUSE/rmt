class Repository < ApplicationRecord

  has_many :products_repositories_associations
  has_many :products, through: :products_repositories_associations

end
