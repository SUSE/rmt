class Product < ApplicationRecord

  has_one :service
  has_many :repositories, through: :service

end
