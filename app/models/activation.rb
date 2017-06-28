class Activation < ApplicationRecord

  belongs_to :system
  belongs_to :service
  has_one :product, through: :service

  validates :system, presence: true
  validates :service, presence: true

end
