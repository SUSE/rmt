class Service < ApplicationRecord

  belongs_to :product

  has_many :activations

  has_many :repositories_services_associations
  has_many :repositories, through: :repositories_services_associations
  has_many :enabled_repositories, -> { where repositories: { enabled: true } }, through: :repositories_services_associations, source: :repository

  validates :product_id, presence: true

  def name
    product.friendly_name.tr(' ', '_')
  end

end
