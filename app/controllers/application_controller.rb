class ApplicationController < ActionController::API

  include ActionController::HttpAuthentication::Basic::ControllerMethods

  def authenticate_system
    authenticate_or_request_with_http_basic('RMT API') do |login, password|
      @system = System.find_by(login: login, password: password)
      if @system
        logger.info "Authenticated system with login '#{login}'"
        @system.touch(:last_seen_at)
      else
        logger.info "Could not find system with login '#{login}' and password '#{password}'"
        error = ActionController::TranslatedError.new('Invalid system credentials')
        error.status = :unauthorized
        raise error
      end
    end
  end
end
