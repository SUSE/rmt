class SystemDataProfile < ApplicationRecord
  validates :profile_type, presence: true
  validates :profile_id, presence: true
  validates :profile_data, presence: true

  def self.process_data_profiles(data_profiles, hwinfo)
    logger.debug("FMCC NEEDS TRANS pre data_profiles hwinfo = #{hwinfo}")
    data_profiles.each do |sdp_type, sdp_info|
      logger.debug("FMCC NEEDS TRANS sdp_type: #{sdp_type}")
      logger.debug("FMCC NEEDS TRANS sdp_info: #{sdp_info}")

      sdp_id = sdp_info.fetch(:profileId, nil)
      sdp_data = sdp_info.fetch(:profileData, nil)

      # search for existing entry in system_data_profiles
      sdp_entry = self.find_by(
        profile_type: sdp_type,
        profile_id: sdp_id,
      )

      # if an entry already exists, update it's last_seen_at if it was
      # last updated more than 1 day ago. Otherwise create a new entry.
      if sdp_entry
        if sdp_entry.last_seen_at.before?(1.day.ago)
          logger.debug("FMCC NEEDS TRANS updating last_seen_at for existing data profile entry for #{sdp_type}, #{sdp_id}")
          sdp_entry.update(last_seen_at: Time.current)
          sdp_entry.save
        end
      else
        # fail if profileData was not provided
        unless sdp_data
          logger.error("FMCC NEEDS TRANS cannot create new data profile entry for #{sdp_type}, #{sdp_id}")
          raise ActionController::TranslatedError.new(
            "FMCC NEEDS TRANS unrecognised profileId provided without profileData"
          )
        end
        logger.debug("FMCC NEEDS TRANS creating new data profile entry for #{sdp_type}, #{sdp_id}")

        sdp_entry = self.new(
          profile_type: sdp_type,
          profile_id: sdp_id,
          profile_data: sdp_data,
          last_seen_at: Time.current
        )

        puts "#{sdp_type}: #{sdp_entry}"
        sdp_entry.save
        logger.info("FMCC NEEDS TRANS created new data profile entry for #{sdp_type}, #{sdp_id}")
      end

      # add profile entry to hwinfo
      hwinfo_field = sdp_type + "_profile"
      hwinfo[hwinfo_field] = { :profileId => sdp_id }
      logger.debug("FMCC NEEDS TRANS hwinfo[#{hwinfo_field}] = #{hwinfo[hwinfo_field]}")
    end
    logger.debug("FMCC NEEDS TRANS post data_profiles hwinfo = #{hwinfo}")
  end
end