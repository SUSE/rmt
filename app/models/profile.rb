class Profile < ApplicationRecord
  # relationships
  # NOTE: for system_profiles we should only trigger cascaded deletes
  # of profiles if system references are removed, but we do not want
  # to remove systems if profiles are removed. Hence need to quieten
  # rubocop complaint here.
  has_many :system_profiles # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :systems, through: :system_profiles

  # validations
  validates :profile_type, presence: true
  validates :identifier, presence: true
  validates :data, presence: true

  def self.filter_profiles(profiles)
    # Profiles can be partitioned into 3 categories:
    #   * complete - containing both the identifier and data fields
    #   * incomplete - missing the data field
    #   * invalid - missing or empty identifier field
    # If a client knows that it has previously submitted a profile
    # with the same type and identifier, it is permitted for it to
    # send up an incomplete version of the profile in an update
    # request

    # Split profiles based upon whether they are valid or not, i.e
    # they contain a non-empty identifier field.
    valid_profiles, invalid_profiles = profiles.partition do |_ptype, pinfo|
      pinfo[:identifier].present?
    end

    # Further split the valid profiles based upon whether they are
    # complete or not, i.e. contain the data field
    complete_profiles, incomplete_profiles = valid_profiles.partition do |_ptype, pinfo|
      pinfo.key?(:data)
    end

    [complete_profiles, incomplete_profiles, invalid_profiles].map do |profile|
      profile.to_h.symbolize_keys
    end
  end

  def self.where_unique_keys(key_tuples)
    # Generate an expanded where clause with one entry per key_tuple
    # and pass the flattened list of key tuples as arguments
    where_clause = key_tuples.map { '(profile_type = ? AND identifier = ?)' }.join(' OR ')
    where_args = key_tuples.flatten
    where(where_clause, *where_args)
  end

  def self.identify_known_profiles(profiles)
    return {} if profiles.empty?

    # Identify profiles that exist
    known_profiles = Profile.where_unique_keys(
      profiles.map { |ptype, pinfo| [ptype, pinfo[:identifier]] }
    )

    # Return the hash representation of the known profiles
    known_profiles.each_with_object({}) do |profile, hash|
      hash[profile.profile_type] = {
        identifier: profile.identifier,
        data: profile.data
      }
    end.symbolize_keys
  end

  def self.ensure_complete_profiles_exist(profiles)
    profiles.map do |ptype, pinfo|
      ensure_profile_exists(ptype, pinfo)
    end
  end

  def self.ensure_profile_exists(ptype, pinfo)
    # Attempt to create a new profile record if an existing one is not
    # found
    profile = where(profile_type: ptype, identifier: pinfo[:identifier]).first_or_create!(data: pinfo[:data])
    logger.debug("ensure_profile_exists: found/created profile - profile_type: #{profile.profile_type}, identifier: #{profile.identifier}")
    profile
  rescue ActiveRecord::RecordNotUnique
    # Only one concurrent create will succeed, others will raise this
    # exception, so just find the newly created record and return it
    profile = find_by(profile_type: ptype, identifier: pinfo[:identifier])
    logger.debug("ensure_profile_exists: found(rescue) profile - profile_type: #{profile.profile_type}, identifier: #{profile.identifier}")
    profile
  end
end
