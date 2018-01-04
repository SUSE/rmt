require 'securerandom'

class Repository < ApplicationRecord

  has_many :repositories_services_associations
  has_many :services, through: :repositories_services_associations
  has_many :systems, through: :services
  has_many :products, -> { distinct }, through: :services

  scope :only_installer_updates, -> { unscope(where: :installer_updates).where(installer_updates: true) }
  scope :only_mirrored, -> { where(mirroring_enabled: true) }
  scope :all_custom_repos, -> { where(is_custom: true) }

  validates :name, presence: true
  validates :external_url, presence: true
  validates :local_path, presence: true


  class << self

    def random_id
      SecureRandom.uuid.delete('-')[0...6]
    end

    def remove_suse_repos_without_tokens!
      where(auth_token: nil).where('external_url LIKE ?', 'https://updates.suse.com%').delete_all
    end

    def only_mirrored_ids
      Repository.only_mirrored.pluck(:id).map do |string|
        clean_id(string)
      end
    end

    # Mangles remote repo URL to make a nicer local path, see specs for examples
    def make_local_path(url)
      uri = URI(url)
      path = uri.path.to_s
      path.gsub!(%r{^/repo}, '') if (uri.hostname == 'updates.suse.com')
      path
    end

    def clean_id(string)
      integer = Integer(string) rescue false
      integer ? integer : string
    end

  end

  def refresh_timestamp!
    touch(:last_mirrored_at)
  end

  def change_mirroring!(mirroring_enabled)
    update_column(:mirroring_enabled, mirroring_enabled)
  end

  def id
    Repository.clean_id(self[:id])
  end

end
