class Api::Connect::V3::Subscriptions::SystemsController < Api::Connect::BaseController

  def announce_system
    # construct the system creation parameters
    create_params = {
      hostname: params[:hostname],
      system_information: info_params(:hwinfo)[:hwinfo].to_json
    }

    # check if any profiles have been provided
    if params.key?(:system_profiles)
      profiles = info_params(:system_profiles)[:system_profiles]
      complete, incomplete, invalid = Profile.filter_profiles(profiles.to_h)

      # all profiles provided to announce_system should be complete
      if incomplete.any? || invalid.any?
        logger.debug("problematic profiles detected: #{incomplete.count} incomplete, #{invalid.count} invalid")
        response.headers['X-System-Profiles-Action'] = 'clear-cache'
      end

      # include the complete profiles in create_params only if
      # complete profiles were actually provided
      create_params[:complete_profiles] = complete if complete.any?
    end

    @system = System.create!(**create_params)

    logger.info("System '#{@system.hostname}' announced")
    respond_with(@system, serializer: ::V3::SystemSerializer, location: nil)
  end

  private

  def info_params(key)
    # Allow all attributes without validating the key structure
    # This is fine since the systems are only internal and RMT users
    # can save in their own database whatever they want.
    # When forwarded to SCC, SCC validates the payload for correctness.
    permit_args = { key => {} }
    params.permit(**permit_args)
  end
end
