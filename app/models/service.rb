class Service < ApplicationRecord

  belongs_to :product

  has_many :activations, dependent: :destroy
  has_many :systems, through: :activations

  has_many :repositories_services_associations
  has_many :repositories, through: :repositories_services_associations
  has_many :enabled_repositories, -> { where repositories: { enabled: true } }, through: :repositories_services_associations, source: :repository

  validates :product_id, presence: true

  def name
    [
      product.name,
      product.release_type,
      (product.arch if product.arch != 'unknown')
    ].compact.join(' ').tr(' ', '_')
  end

end
