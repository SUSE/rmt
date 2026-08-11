class Api::Connect::V3::Subscriptions::SystemsController < Api::Connect::BaseController

  def announce_system
    # Construct the system creation parameters
    create_params = {
      hostname: params[:hostname],
      system_information: info_params(:hwinfo)[:hwinfo].to_json
    }

    # Check if any profiles have been provided
    process_system_profiles(create_params)

    @system = create_system_retry_if_profiles_provided(create_params)

    logger.info("System '#{@system.hostname}' announced")
    respond_with(@system, serializer: ::V3::SystemSerializer, location: nil)
  end

  private

  def create_system_retry_if_profiles_provided(params)
    System.create!(**params)
  rescue StandardError => e
    # Only retry if profiles were present or haven't already been stripped;
    # prevents infinite retry loops for errors not related to profiles.
    # In the event of a retry set the response header telling the client
    # to send full profiles next time.
    if params[:complete_profiles]
      logger.warn("System creation failed with profiles, retrying without: #{e.message}")
      params.delete(:complete_profiles)
      response.headers['X-System-Profiles-Action'] = 'clear-cache'
      System.create!(**params)
    else
      raise
    end
  end

  def process_system_profiles(create_params)
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
