class Api::Connect::BaseController < ApplicationController

  respond_to :json

  rescue_from ActionController::TranslatedError do |error|
    render json: { type: 'error', error: error.message, localized_error: error.localized_message }, status: error.status, location: nil
  end

  protected

  def require_params(keys)
    payload = JSON.parse(params[:payload]) if params[:payload] && params[:payload].is_a?(String)
    parameters = payload ? payload : params

    missing_keys = []
    keys.map(&:to_s).each do |key|
      missing_keys << key unless parameters.key?(key)
    end

    raise ActionController::ParameterMissingTranslated.new(*missing_keys) if missing_keys.any?
  end

  def authenticate_system
    authenticate_or_request_with_http_basic('Potato API') do |login, password|
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
