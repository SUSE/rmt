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
  has_many :system_profiles, dependent: :destroy
  has_many :system_data_profiles, -> { distinct }, through: :system_profiles

  validates :system_token, uniqueness: { scope: %i[login password], case_sensitive: false }

  alias_attribute :scc_synced_at, :scc_registered_at

  accepts_nested_attributes_for :system_data_profiles

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

  def self.filter_data_profiles(profiles)
    # split profiles into those that validly contain a profileId field
    # and those that don't
    valid_profiles, invalid_profiles = profiles.partition do |_dp_type, dp_info|
      dp_info.key?(:profileId)
    end

    # further filter the valid profiles into those that are complete,
    # have a profileData field, and those that don't
    complete_profiles, incomplete_profiles = valid_profiles.partition do |_dp_type, dp_info|
      dp_info.key?(:profileData)
    end

    [complete_profiles.to_h, incomplete_profiles.to_h, invalid_profiles.to_h]
  end

  def self.identify_existing_data_profiles(profiles)
    return {} if profiles.empty?

    # identify complete profiles that exist
    found_sdps = SystemDataProfile.where_unique_keys(
      profiles.map { |sdp_type, sdp_info| [sdp_type, sdp_info[:profileId]] }
    )

    # convert the found entries to a hash with symbolised keys
    found_sdps.each_with_object({}) do |sdp, hash|
      hash[sdp.profile_type] = {
        profileId: sdp.profile_id,
        profileData: sdp.profile_data
      }
    end.symbolize_keys
  end

  def data_profiles=(profiles)
    # Even if profiles is empty we want to process it to allow any
    # existing data profile associations to be removed

    # permitted number of retries for upsert attempts
    remaining_retries = 3

    begin
      # create any provided profiles as part of a single upsert_all()
      # request to avoid deadlock.
      unless profiles.empty?
        create_profiles_if_needed(profiles, Time.current)
      end

      # retrieve profile entries matching all provided profiles for this system
      system_profiles = SystemDataProfile.where_unique_keys(
        profiles.map { |sdp_type, sdp_info| [sdp_type, sdp_info[:profileId]] }
      )

      # setup associations this system for all profiles
      self.system_data_profiles = system_profiles

    # retry if a racing deregister triggered a cascaded delete of a
    # data profile, while there are remaining retry attempts
    rescue ActiveRecord::InvalidForeignKey
      if remaining_retries > 0
        logger.debug("FMCC NEEDS TRANS caught invalid forign key, remaining retries #{remaining_retries}")
        remaining_retries -= 1
        retry
      else
        logger.debug('FMCC NEEDS TRANS caught invalid forign key, retries exhausted')
        raise
      end
    end
  end

  def create_profiles_if_needed(profiles, current_time = nil)
    # init current_time if not specified
    current_time = Time.current if current_time.nil?

    # create/update any provided complete profiles as part of a
    # single upsert_all() request to avoid deadlock.
    logger.debug("FMCC NEEDS TRANS create/update complete profiles #{profiles}")
    upsert_rows = profiles.map do |sdp_type, sdp_info|
      {
        profile_type: sdp_type,
        profile_id: sdp_info[:profileId],
        profile_data: sdp_info[:profileData],
        created_at: current_time
      }
    end
    SystemDataProfile.upsert_all(upsert_rows)
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
