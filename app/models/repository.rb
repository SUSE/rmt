class Repository < ApplicationRecord

  has_many :repositories_services_associations
  has_many :services, through: :repositories_services_associations
  has_many :systems, through: :services
  has_many :products, -> { distinct }, through: :services

  scope :only_installer_updates, -> { unscope(where: :installer_updates).where(installer_updates: true) }
  scope :only_mirrored, -> { where(mirroring_enabled: true) }
  scope :only_custom, -> { where(custom: true) }
  scope :only_scc, -> { where(custom: false) }

  validates :name, presence: true
  validates :external_url, presence: true
  validates :local_path, presence: true

  before_destroy :ensure_destroy_possible
  before_create :set_unique_id

  class << self

    def remove_suse_repos_without_tokens!
      where(auth_token: nil).where('external_url LIKE ?', 'https://updates.suse.com%').delete_all
    end

    # Mangles remote repo URL to make a nicer local path, see specs for examples
    def make_local_path(url)
      uri = URI(url)
      path = uri.path.to_s
      path.gsub!(%r{^/repo}, '') if (uri.hostname == 'updates.suse.com')
      (path == '') ? '/' : path
    end

  end

  def refresh_timestamp!
    touch(:last_mirrored_at)
  end

  def change_mirroring!(mirroring_enabled)
    update_column(:mirroring_enabled, mirroring_enabled)
  end

  def self.generate_unique_id
    (0...5).map { (97 + rand(26)).chr }.join
  end

  private

  def set_unique_id
    return unless (custom? && !unique_id)
    generated_id = nil
    repo = nil

    5.times do
      generated_id = self.class.generate_unique_id
      repo = Repository.find_by(unique_id: generated_id)
      break unless repo
    end

    raise 'Can not generate unique custom repo ID' if repo

    self.unique_id = generated_id
  end

  def ensure_destroy_possible
    throw(:abort) unless custom?
  end

end
