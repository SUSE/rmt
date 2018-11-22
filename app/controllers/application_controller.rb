class ApplicationController < ActionController::API

  include ActionController::HttpAuthentication::Basic::ControllerMethods

  rescue_from ActionController::TranslatedError do |error|
    render json: { type: 'error', error: error.message, localized_error: error.localized_message }, status: error.status, location: nil
  end

  def authenticate_system
    authenticate_or_request_with_http_basic('RMT API') do |login, password|
      @system = System.find_by(login: login, password: password)
      if @system
        logger.info _('Authenticated system with login \"%{login}\"') % { login: login }
        @system.touch(:last_seen_at)
      else
        logger.info _('Could not find system with login \"%{login}\" and password \"%{password}\"') % { login: login, password: password }
        error = ActionController::TranslatedError.new(N_('Invalid system credentials'))
        error.status = :unauthorized
        raise error
      end
    end
  end
end
