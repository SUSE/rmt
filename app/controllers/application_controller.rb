class ApplicationController < ActionController::API
  SYSTEM_TOKEN_HEADER = 'System-Token'.freeze

  include ActionController::HttpAuthentication::Basic::ControllerMethods

  rescue_from ActionController::TranslatedError do |error|
    render json: { type: 'error', error: error.message, localized_error: error.localized_message }, status: error.status, location: nil
  end

  def authenticate_system
    authenticate_or_request_with_http_basic('RMT API') do |login, password|
      @systems = System.get_by_credentials(login, password)
      if @systems.present?
        @system = find_system_by_token_header(@systems)

        # If SYSTEM_TOKEN_HEADER is present, RMT assumes the client uses a SUSEConnect version
        # that supports this feature. In this case, refresh the token and include it in the response.
        if request.headers.key?(SYSTEM_TOKEN_HEADER)
          @system.update(last_seen_at: Time.zone.now, system_token: SecureRandom.uuid)
          headers[SYSTEM_TOKEN_HEADER] = @system.system_token
        # only update last_seen_at each 3 minutes,
        # so that a system that calls SCC every second doesn't write + lock the database row
        elsif !@system.last_seen_at || @system.last_seen_at < 3.minutes.ago
          @system.touch(:last_seen_at)
        end
        true
      else
        logger.info _('Could not find system with login \"%{login}\" and password \"%{password}\"') %
          { login: login, password: password }
        error = ActionController::TranslatedError.new(N_('Invalid system credentials'))
        error.status = :unauthorized
        raise error
      end
    end
  end

  private

  # Token mechanism to detect duplicated systems.
  # 1: system doesn't send a token header (old SUSEConnect version)
  # 2: system sends a token, and it matches an existing system with that token
  # 3: system sends an empty token, it matches an existing system without token
  #    -> it's a new system (because the 'announce_system' call doesn't set the token yet)
  #       or a system that upgraded to a SUSEConnect version that supports tokens
  # 4: system sends an empty token, but a system with credentials and token exists (duplicate)
  # 5: system sends a token, it matches an existing system but mismatch the token (duplicate)

  def find_system_by_token_header(systems)
    return nil if systems.blank?

    # 1st case
    unless request.headers.key?(SYSTEM_TOKEN_HEADER)
      logger.info _('System with login \"%{login}\" authenticated without token header') %
        { login: systems.first.login }
      return systems.first
    end

    # 2nd/3rd case
    system_token = request.headers[SYSTEM_TOKEN_HEADER].presence
    system = systems.find { |s| s.system_token == system_token }
    if system
      logger.info _('System with login \"%{login}\" authenticated with token \"%{system_token}\"') %
        { login: system.login, system_token: system_token }
      return system
    end

    # 4th/5th case
    system = systems.first
    system.dup.tap do |ns|
      ns.created_at = Time.zone.now
      ns.system_token = system_token
      ns.activations = system.activations.map(&:dup)
      ns.hw_info = system.hw_info.dup
      ns.save!
      logger.info _('System with login \"%{login}\" (ID %{new_id}) authenticated and duplicated from ID %{base_id} due to token mismatch') %
        { login: ns.login, new_id: ns.id, base_id: system.id }
    end
  end
end
