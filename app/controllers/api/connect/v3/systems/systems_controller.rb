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

    # if a set of data profiles has been provided, we should process it,
    # even if empty, to allow an empty hash to indicate the removal of
    # existing data profiles associations for this system
    if params.key? :data_profiles
      data_profiles = info_params(key: :data_profiles)[:data_profiles]
      complete_profiles, incomplete_profiles, invalid_profiles = System.filter_data_profiles(data_profiles.to_h)

      # need to check if any of the imcomplete profiles don't exist
      existing_incomplete_profiles = System.identify_existing_data_profiles(incomplete_profiles)
      if existing_incomplete_profiles.count != incomplete_profiles.count
        response.headers['X-System-Profiles-Action'] = 'clear-cache'
      end

      # TODO: Should we have different header values for incomplete vs invalid profiles?
      if invalid_profiles.any?
        response.headers['X-System-Profiles-Action'] = 'clear-cache'
      end

      # combine the complete and existing incomplete profile
      update_profiles = complete_profiles.merge(existing_incomplete_profiles)

      @system.update(data_profiles: update_profiles)
    end

    # Since the payload is handled by rails all values are converted to string
    # e.g. cpus: 16 becomes cpus: "16". We save this as string for now and expect
    # SCC to handle the conversion correctly
    @system.system_information = @system.system_information_hash.update(info_params(key: :hwinfo)[:hwinfo]).to_json

    if @system.save
      logger.info(N_("Updated system information for host '%s'") % @system.hostname)
    end

    respond_with(@system, serializer: ::V3::SystemSerializer)
  end

  def deregister
    respond_with(@system.destroy, serializer: ::V3::SystemSerializer)
  end

  private

  def info_params(key:)
    # Allow all attributes without validating the key structure
    # This is fine since the systems are only internal and RMT users
    # can save in their own database whatever they want.
    # When forwarded to SCC, SCC validates the payload for correctness.
    permit_args = { key => {} }
    params.permit(permit_args)
  end
end
