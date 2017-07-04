class Api::Connect::BaseController < ApplicationController

  respond_to :json

  protected

  def respond_with_error(status: :unprocessable_entity, **args)
    render json: { type: 'error', error: args[:message], localized_error: args[:localized_message] }, status: status, location: nil
  end

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
        untranslated = N_('Invalid system credentials')
        respond_with_error({ message: untranslated, localized_message: _(untranslated), status: :unauthorized })
      end
    end
  end

end
