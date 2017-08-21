class Repository < ApplicationRecord

  has_many :repositories_services_associations
  has_many :services, through: :repositories_services_associations
  has_many :systems, through: :services
  has_many :products, -> { distinct }, through: :services

  validates :name, presence: true
  validates :external_url, presence: true
  validates :local_path, presence: true

  # Mangles remote repo URL to make a nicer local path, see specs for examples
  def self.make_local_path(url)
    uri = URI(url)
    path = uri.path.to_s
    path.gsub!(%r{^/repo}, '') if (uri.hostname == 'updates.suse.com')
    path
  end

end
