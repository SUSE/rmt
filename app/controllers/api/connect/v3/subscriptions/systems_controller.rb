class Api::Connect::V3::Subscriptions::SystemsController < Api::Connect::BaseController

  def announce_system
    @system = System.create!(hostname: params[:hostname], system_information: info_params(:hwinfo)[:hwinfo].to_json)

    # Extract any complete profiles, setting the profile response header
    # if invalid or incomplete profiles are detected.
    profile_params = {}
    extract_complete_profiles(profile_params)

    # Update with any provided profiles, just setting the response header
    # if and logging a message if any errors occur.
    update_system_profiles(profile_params)

    logger.info("System '#{@system.hostname}' announced")
    respond_with(@system, serializer: ::V3::SystemSerializer, location: nil)
  end

  private

  def update_system_profiles(profile_params)
    # do nothing if profile_params is empty
    return unless profile_params.any?

    @system.update!(**profile_params)
  rescue StandardError => e
    # If any errors occur while updating the profiles, log a warning
    # and set the response header but do not fail the request.
    logger.warn("System '#{@system.hostname}' profile update failed: #{e.message}")
    response.headers['X-System-Profiles-Action'] = 'clear-cache'
  end

  def extract_complete_profiles(profile_params)
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

      # Include the complete profiles in profile_params only if
      # complete profiles were actually provided
      if complete.any?
        logger.debug("valid complete profiles detected: #{complete.keys}")
        profile_params[:complete_profiles] = complete
      end
    end
  end

  def info_params(key)
    # Allow all attributes without validating the key structure
    # This is fine since the systems are only internal and RMT users
    # can save in their own database whatever they want.
    # When forwarded to SCC, SCC validates the payload for correctness.
    permit_args = { key => {} }
    params.permit(**permit_args)
  end
end
