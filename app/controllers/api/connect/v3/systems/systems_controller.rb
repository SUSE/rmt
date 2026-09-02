class Api::Connect::V3::Systems::SystemsController < Api::Connect::BaseController

  before_action :authenticate_system
  after_action :refresh_system_token, only: [:update], if: -> { request.headers.key?(SYSTEM_TOKEN_HEADER) }

  def update
    System.transaction do
      # SELECT ... FOR UPDATE: blocks a concurrent deregistration until this
      # request commits, and raises RecordNotFound if it already committed
      # Locked by id rather than `@system.lock!`: `lock!` rejects a record with
      # unpersisted changes, and `after_initialize :init` dirties any system
      # with a NULL registered_at
      begin
        System.lock.find(@system.id)
      rescue ActiveRecord::RecordNotFound
        raise system_deregistered_error
      end

      perform_update
    end

    respond_with(@system, serializer: ::V3::SystemSerializer)
  rescue ActiveRecord::InvalidForeignKey
    raise system_deregistered_error
  end

  def deregister
    respond_with(@system.destroy, serializer: ::V3::SystemSerializer)
  end

  private

  def system_deregistered_error
    logger.info(N_("System '%s' was deregistered while its update was in flight") % @system.login)
    error = ActionController::TranslatedError.new(N_('Invalid system credentials'))
    error.status = :unauthorized
    error
  end

  def perform_update
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

    # If a system_profiles param has been provided, process
    # the provided profiles
    if params.key?(:system_profiles)
      profiles = info_params(:system_profiles)[:system_profiles]

      # Partition profiles into three categories, namely complete,
      # incomplete (missing the data field), and invalid (missing
      # the identifier field)
      complete, incomplete, invalid = Profile.filter_profiles(profiles.to_h)

      # Further refine the incomplete profiles to identify any that
      # are known, and retrieve complete versions of them
      known_incomplete = Profile.identify_known_profiles(incomplete)

      # Determine the unknown profiles in incomplete group, if any
      unknown_incomplete_types = incomplete.keys - known_incomplete.keys

      # If any of the provided profiles is invalid or if any of the
      # incomplete profiles aren't known, set the response header
      if invalid.any? || unknown_incomplete_types.any?
        logger.debug("problematic invalid (missing identifier field) profiles detected: #{invalid.keys}") if invalid.any?
        logger.debug("problematic unrecognised incomplete (missing data field) profiles detected: #{unknown_incomplete_types}") if unknown_incomplete_types.any?
        response.headers['X-System-Profiles-Action'] = 'clear-cache'
      end

      # Aggregate the provided complete profiles with the retrieved
      # complete profiles associated with known incompletes, updating
      # the system if applicable.
      aggregated_completes = complete.merge(known_incomplete)
      if aggregated_completes.any?
        logger.debug("valid aggregated complete profiles detected: #{aggregated_completes.keys}")
        @system.update(complete_profiles: aggregated_completes)
      end
    end

    # Since the payload is handled by rails all values are converted to string
    # e.g. cpus: 16 becomes cpus: "16". We save this as string for now and expect
    # SCC to handle the conversion correctly
    @system.system_information = @system.system_information_hash.update(info_params(:hwinfo)[:hwinfo]).to_json

    if @system.save
      logger.info(N_("Updated system information for host '%s'") % @system.hostname)
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
