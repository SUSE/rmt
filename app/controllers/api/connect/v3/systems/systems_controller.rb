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

    hwinfo = hwinfo_params[:hwinfo]

    # list of known system data profile types to check for
    sdp_types = [:mod_list, :pci_data]

    sdp_types.each do |sdp_type|
      puts "sdp_type: #{sdp_type}"
      #logger.info(N_("Checking for sdp_type %s"), sdp_type)
      hwinfo_sdp = hwinfo.fetch(sdp_type, nil)

      # skip if no entry exist in hwinfo for specified type
      next unless hwinfo_sdp

      puts "hwinfo_sdp: #{hwinfo_sdp}"
      sdp_id = hwinfo_sdp.fetch(:profileId, nil)
      puts "#{sdp_type}[:profileId]: #{sdp_id.inspect}"
      sdp_data = hwinfo_sdp.fetch(:profileData, nil)
      puts "#{sdp_type}[:profileData]: #{sdp_data.inspect}"

      # search for existing entry in system_data_profiles
      sdp_entry = SystemDataProfile.find_by(
        profile_type: sdp_type,
        profile_id: sdp_id,
      )

      # add a new entry to system data profiles if not found
      unless sdp_entry
        sdp_entry = SystemDataProfile.new(
          profile_type: sdp_type,
          profile_id: sdp_id,
          profile_data: sdp_data
        )

        puts "#{sdp_type}: #{sdp_entry}"
        sdp_entry.save
      end

      # delete the profileData entry from the associated hwinfo entry
      hwinfo[sdp_type].delete(:profileData)
      puts "hwinfo[#{sdp_type}] = #{hwinfo[sdp_type]}"
    end

    # Since the payload is handled by rails all values are converted to string
    # e.g. cpus: 16 becomes cpus: "16". We save this as string for now and expect
    # SCC to handle the conversion correctly
    @system.system_information = @system.system_information_hash.update(hwinfo).to_json

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
