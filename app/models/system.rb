class System < ApplicationRecord
  # This value has meaning/relevance only used in public cloud scenarios
  # This value indicates that the system is using
  # NOT_APPLICABLE (systems outside the public cloud),
  # PAYG (pay as you go),
  # BYOS (bring your own subscription) or
  # a mix of both (hybrid).
  enum proxy_byos_mode: { not_applicable: 0, payg: 1, byos: 2, hybrid: 3 }

  after_initialize :init

  has_many :activations, dependent: :delete_all # this is set this way because of performance reasons
  has_many :services, through: :activations
  has_many :repositories, -> { distinct }, through: :services
  has_many :products, -> { distinct }, through: :services
  has_many :system_uptimes, dependent: :destroy
  has_many :system_profiles, dependent: :destroy # TODO: can we used :destroy_async?
  has_many :profiles, -> { distinct }, through: :system_profiles

  validates :system_token, uniqueness: { scope: %i[login password], case_sensitive: false }

  alias_attribute :scc_synced_at, :scc_registered_at

  accepts_nested_attributes_for :profiles

  def init
    self.login ||= System.generate_secure_login
    self.password ||= System.generate_secure_password
    self.registered_at ||= Time.zone.now
  end

  # Generate secure token for System login
  def self.generate_secure_login
    generated_login = nil
    # Generate a new login as long as it is not in use.
    while !generated_login || System.find_by(login: generated_login)
      # The login credentials has to have the prefix "SCC_" in order to recognize SCC authentication
      generated_login = "SCC_#{build_secure_token}"
    end
    generated_login
  end

  def cloud_provider
    system_information_hash.fetch(:cloud_provider, nil)
  end

  def system_information_hash
    # system_information is checked for valid JSON on save. It is safe
    # to assume the structure is valid.
    JSON.parse(system_information || '{}').symbolize_keys
  end

  def set_system_information(key, value)
    update(system_information: system_information_hash.update(key => value).to_json)
  end

  # Generate secure token for System password
  def self.generate_secure_password
    build_secure_token[0..15]
  end

  def self.build_secure_token
    SecureRandom.uuid.delete('-')
  end

  def self.get_by_credentials(login, password)
    where(login: login, password: password).order(:id)
  end

  def update_system_uptime(day: nil, hours: nil)
    system_uptime = system_uptimes.find_by(online_at_day: day)
    if system_uptime
      system_uptime.update!(online_at_hours: hours)
    else
      system_uptimes.create!(online_at_day: day, online_at_hours: hours)
    end
  end

  def update_instance_data(instance_data)
    update!(instance_data: instance_data)
  end

  def complete_profiles=(profiles_hash)
    # NOTE: All provided profiles in profiles_hash must be complete
    logger.debug("assigning complete profiles: #{profiles_hash.keys}")

    # Lookup or create Profile records for the provided profiles
    provided_profiles = Profile.ensure_complete_profiles_exist(profiles_hash)

    # Determine the set of Profile record ids for the provided profiles
    # and determine which ids are new, and which can be dropped, using
    # the Rails provided profile_ids reader to retrieve the current set
    # of associated ids.
    provided_ids = provided_profiles.map(&:id)
    new_ids = provided_ids - profile_ids
    dropped_ids = profile_ids - provided_ids

    # Remove any associations for dropped profile records
    if dropped_ids.any?
      profiles.delete(Profile.where(id: dropped_ids))
    end

    # Add new associations for any Profile records identified as
    # being new in the set of provided profiles
    if new_ids.any?
      profiles << provided_profiles.select do |prof|
        new_ids.include?(prof.id)
      end
    end
  end

  before_update do |system|
    # reset SCC sync timestamp so that the system can be re-synced on change
    system.scc_synced_at = nil
  end

  after_destroy do |system|
    if system.scc_system_id
      DeregisteredSystem.find_or_create_by(scc_system_id: system.scc_system_id)
    end
  end
end
