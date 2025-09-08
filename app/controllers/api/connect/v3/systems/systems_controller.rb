class Api::Connect::V3::Systems::SystemsController < Api::Connect::BaseController

  before_action :authenticate_system
  after_action :refresh_system_token, only: [:update], if: -> { request.headers.key?(SYSTEM_TOKEN_HEADER) }

  def update
    if params[:online_at].present?
      params[:online_at].each do |online_at|
        dthours = online_at.split(':')
        if dthours.count == 2
          online_day = online_at.split(':')[0]
          online_hours = online_at.split(':')[1]
          @system.update_system_uptime(day: online_day,
                                       hours: online_hours)
        else
          logger.error(N_("Uptime data is malformed '%s'") % online_at)
        end
      end
    end

    @system.hostname = params[:hostname]

    hwinfo = params[:hwinfo]

    logger.debug("FMCC NEEDS TRANS pre data_profiles hwinfo = #{hwinfo}")

    if params[:data_profiles].present?
      params[:data_profiles].each do |sdp_type, sdp_info|
        logger.debug("FMCC NEEDS TRANS sdp_type: #{sdp_type}")
        logger.debug("FMCC NEEDS TRANS sdp_info: #{sdp_info}")

        sdp_id = sdp_info.fetch(:profileId, nil)
        sdp_data = sdp_info.fetch(:profileData, nil)

        # search for existing entry in system_data_profiles
        sdp_entry = SystemDataProfile.find_by(
          profile_type: sdp_type,
          profile_id: sdp_id,
        )

        # add a new entry to system data profiles if not found
        unless sdp_entry
          unless sdp_data
            logger.error("FMCC NEEDS TRANS cannot create new data profile entry for #{sdp_type}, #{sdp_id}")
            raise ActionController::TranslatedError.new(
              "FMCC NEEDS TRANS unrecognised profileId provided without profileData"
            )
          end
          logger.debug("FMCC NEEDS TRANS creating new data profile entry for #{sdp_type}, #{sdp_id}")

          sdp_entry = SystemDataProfile.new(
            profile_type: sdp_type,
            profile_id: sdp_id,
            profile_data: sdp_data
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
    end

    logger.debug("FMCC NEEDS TRANS post data_profiles hwinfo = #{hwinfo}")
    # Since the payload is handled by rails all values are converted to string
    # e.g. cpus: 16 becomes cpus: "16". We save this as string for now and expect
    # SCC to handle the conversion correctly
    @system.system_information = @system.system_information_hash.update(hwinfo_params[:hwinfo]).to_json

    if @system.save
      logger.info(N_("Updated system information for host '%s'") % @system.hostname)
    end

    respond_with(@system, serializer: ::V3::SystemSerializer)
  end

  def deregister
    respond_with(@system.destroy, serializer: ::V3::SystemSerializer)
  end

  private

  def hwinfo_params
    # Allow all attributes without validating the key structure
    # This is fine since the systems are only internal and RMT users
    # can save in their own database whatever they want.
    # When forwarded to SCC, SCC validates the payload for correctness.
    params.permit(hwinfo: {})
  end
end
