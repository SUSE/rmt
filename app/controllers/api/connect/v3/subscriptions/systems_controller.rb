class Api::Connect::V3::Subscriptions::SystemsController < Api::Connect::BaseController

  def announce_system

    create_params = {
      hostname: params[:hostname],
      system_information: info_params(key: :hwinfo)[:hwinfo].to_json
    }

    # check if any data profiles have been provided
    data_profiles = info_params(key: :data_profiles)[:data_profiles]
    if params[:data_profiles].present?
      complete_profiles, incomplete_profiles, invalid_profiles = System.filter_data_profiles(data_profiles.to_h)

      # if any of the provided profiles are incomplete or invalid, then
      # set response header indicating that the cache needs to be cleared
      # TODO: Should we have different header values for incomplete vs invalid profiles?
      if incomplete_profiles.any? || invalid_profiles.any?
        response.headers['X-System-Profiles-Action'] = 'clear-cache'
      end

      # only include a data_profiles entry in the create params if
      # there are valid complete profiles provided.
      if complete_profiles.any?
        create_params[:data_profiles] = complete_profiles
      end
    end

    @system = System.create!(
      # hostname: params[:hostname],
      # system_information: info_params(key: :hwinfo)[:hwinfo].to_json,
      # data_profiles: complete_profiles
      **create_params
    )

    logger.info("System '#{@system.hostname}' announced")
    respond_with(@system, serializer: ::V3::SystemSerializer, location: nil)
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
