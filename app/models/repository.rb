class Repository < ApplicationRecord

  has_many :repositories_services_associations
  has_many :services, through: :repositories_services_associations
  has_many :systems, through: :services
  has_many :products, -> { distinct }, through: :services

  scope :only_installer_updates, -> { unscope(where: :installer_updates).where(installer_updates: true) }
  scope :only_mirrored, -> { where(mirroring_enabled: true) }

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

  def refresh_timestamp!
    update_column(:last_mirrored_at, DateTime.now.utc)
  end

  def change_mirroring!(mirroring_enabled)
    update_column(:mirroring_enabled, mirroring_enabled)
  end

  def self.remove_suse_repos_without_tokens!
    where(auth_token: nil).where('external_url LIKE ?', 'https://updates.suse.com%').delete_all
  end

end
