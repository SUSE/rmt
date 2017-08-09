class Repository < ApplicationRecord

  has_many :repositories_services_associations
  has_many :services, through: :repositories_services_associations
  has_many :systems, through: :services
  has_many :products, -> { distinct }, through: :services

  validates :name, presence: true
  validates :external_url, presence: true
  validates :local_path, presence: true

  def make_local_path(url)
    URI(url).path.to_s.gsub(/^\/repo/, '')
  end

end
