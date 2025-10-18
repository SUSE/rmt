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
  has_many :system_data_profiles, through: :system_profiles

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

  def data_profiles=(data_profiles)
    #logger.debug("FMCC NEEDS TRANS create/update system_data_profiles based upon #{data_profiles}")
    #logger.debug("FMCC NEEDS TRANS provided data_profiles is a #{data_profiles.class}")
    #logger.debug("FMCC NEEDS TRANS provided data_profiles responds to .to_h #{data_profiles.respond_to?(:to_h)}")
    #logger.debug("FMCC NEEDS TRANS provided data_profiles responds to .map #{data_profiles.respond_to?(:map)}")

    return if data_profiles.empty?

    complete_profiles, incomplete_profiles = data_profiles.partition do |_, sdp_info|
      sdp_info.key?(:profileData)
    end

    # permitted number of retries
    remaining_retries = 3

    begin
      current_time = Time.current

      # create/update any provided complete data profiles as part of a
      # single upsert_all() request to avoid deadlock.
      unless complete_profiles.empty?
        logger.debug("FMCC NEEDS TRANS create/update complete data profiles #{complete_profiles}")
        upsert_rows = complete_profiles.map do |sdp_type, sdp_info|
          {
            profile_type: sdp_type,
            profile_id: sdp_info[:profileId],
            profile_data: sdp_info[:profileData],
            last_seen_at: current_time,
            created_at: current_time,
          }
        end
        SystemDataProfile.upsert_all(upsert_rows)
      end

      # verify that all incomplete profiles already exist
      unless incomplete_profiles.empty?
        logger.debug("FMCC NEEDS TRANS check for existence of incomplete data profiles #{incomplete_profiles}")
        if SystemDataProfile.Where_Unique_Keys(
            incomplete_profiles.map { |sdp_type, sdp_info| [sdp_type, sdp_info[:profileId]] },
          ).count != required_profiles.length
          # TODO handle this better.
          # Should
          #   - ensure request completes with HTTP Resent Content (205) status
          #   - continue processing for valid profiles
          errors.add(:base, "FMCC NEEDS TRANS missing data for one or more unrecognised profiles")
          return
        end
      end

      # retrieve profile entries matching all provided data profiles for this system
      system_profiles = SystemDataProfile.Where_Unique_Keys(
        data_profiles.map { |sdp_type, sdp_info| [sdp_type, sdp_info[:profileId]] },
      )

      # update any last_seen_at values that are older than a day
      stale_last_seen_ats = system_profiles.select { |sdp| sdp.last_seen_at < 1.day.ago }
      unless stale_last_seen_ats.empty?
        logger.debug("FMCC NEEDS TRANS updating last_seen_at for data profiles #{stale_last_seen_ats}")
        upsert_rows = stale_last_seen_at.map do |sdp_type, sdp_info|
          {
            profile_type: sdp_type,
            profile_id: sdp_info[:profileId],
            last_seen_at: current_time,
          }
        end
        SystemDataProfile.upsert_all(upsert_rows)
      end

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
        logger.debug("FMCC NEEDS TRANS caught invalid forign key, retries exhausted")
        raise
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
