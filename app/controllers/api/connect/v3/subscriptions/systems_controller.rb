class Api::Connect::V3::Subscriptions::SystemsController < Api::Connect::BaseController

  def announce_system
    # Construct the system creation parameters
    create_params = {
      hostname: params[:hostname],
      system_information: info_params(:hwinfo)[:hwinfo].to_json
    }

    # Check if any profiles have been provided
    if params.key?(:system_profiles)
      profiles = info_params(:system_profiles)[:system_profiles]

      # Partition profiles into three categories, namely complete,
      # incomplete (missing the data field), and invalid (missing
      # the identifier field)
      complete, incomplete, invalid = Profile.filter_profiles(profiles.to_h)

      # All profiles provided to announce_system should be complete; set
      # response header if any invalid or incomplete profiles were provided.
      if incomplete.any? || invalid.any?
        logger.debug("problematic incomplete (missing data field) profiles detected: #{incomplete.keys}") if incomplete.any?
        logger.debug("problematic invalid (missing identifier field) profiles detected: #{invalid.keys}") if invalid.any?
        response.headers['X-System-Profiles-Action'] = 'clear-cache'
      end

      # Include the complete profiles in create_params only if
      # complete profiles were actually provided
      if complete.any?
        logger.debug("valid complete profiles detected: #{complete.keys}")
        create_params[:complete_profiles] = complete
      end
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
