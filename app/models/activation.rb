class Activation < ApplicationRecord

  belongs_to :system
  belongs_to :service
  has_one :product, through: :service

end
