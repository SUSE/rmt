class Repository < ApplicationRecord

  has_many :repositories_services_associations
  has_many :services, through: :repositories_services_associations
  has_many :systems, through: :services
  has_many :products, -> { distinct }, through: :services

  scope :only_installer_updates, -> { where(installer_updates: true) }
  scope :only_mirroring_enabled, -> { where(mirroring_enabled: true) }
  scope :only_fully_mirrored, -> { where(mirroring_enabled: true).where.not(last_mirrored_at: nil) }
  scope :only_enabled, -> { where(enabled: true) }
  scope :only_custom, -> { where(scc_id: nil) }
  scope :only_scc, -> { where.not(scc_id: nil) }
  scope :exclude_installer_updates, -> { where(installer_updates: false) }

  validates :name, presence: true
  validates :external_url, presence: true
  validates :local_path, presence: true
  validates :friendly_id, presence: true

  before_destroy :ensure_destroy_possible

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

    def make_friendly_id(input)
      sanitized_input = input.to_s.strip.gsub(/\s+/, '-').gsub(/[^[:alnum:]\-_]/, '').downcase

      # Don't modify numeric input (scc_ids) and, if the friendly_id doesn't exist yet, allow it without a postfix
      return sanitized_input if /^[0-9]+$/.match?(sanitized_input) || Repository.default_scoped.where(friendly_id: sanitized_input).empty?

      # The requested friendly_id was taken, so we need to find a working number to append
      append_base = "#{sanitized_input}-"
      regexp = /(.*)-(\d+)\z/

      potential_conflicts = Repository.default_scoped.select(:friendly_id).where('friendly_id LIKE ?', "#{append_base}%").collect(&:friendly_id)
      max = potential_conflicts.map do |conflict|
        match = conflict.match(regexp)
        sql = sanitize_sql_array(['SELECT ? = ?', sanitized_input, match[1].to_s])
        connection.execute(sql).first[0] == 1 ? match[2].to_i : 0
      end.max
      max ||= 0

      "#{append_base}#{max + 1}"
    end

  end

  def refresh_timestamp!
    touch(:last_mirrored_at)
  end

  def change_mirroring!(mirroring_enabled)
    update_column(:mirroring_enabled, mirroring_enabled)
  end

  def custom?
    scc_id.nil?
  end

  private

  def ensure_destroy_possible
    throw(:abort) unless custom?
  end

end
