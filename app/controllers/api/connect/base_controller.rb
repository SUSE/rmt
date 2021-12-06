class Api::Connect::BaseController < ApplicationController

  include ActionController::HttpAuthentication::Token::ControllerMethods

  respond_to :json

  protected

  def require_params(keys)
    payload = JSON.parse(params[:payload]) if params[:payload] && params[:payload].is_a?(String)
    parameters = payload ? payload : params

    missing_keys = []
    keys.map(&:to_s).each do |key|
      missing_keys << key unless parameters.key?(key)
    end

    if missing_keys.any?
      raise ActionController::TranslatedError.new(
        N_('Required parameters are missing or empty: %s'),
        missing_keys.join(', ')
      )
    end
  end

  def authenticate_with_token
    authenticate_or_request_with_http_token do |token, _options|
      @subscription = Subscription.find_by(regcode: token)
      if !@subscription
        logger.info "Token authentication with invalid regcode: '#{token}'"
        error_message = N_('Unknown Registration Code.')
      elsif !@subscription.active?
        logger.info "Token authentication with not activated regcode: '#{token}'"
        error_message = N_('Not yet activated Registration Code. Visit https://scc.suse.com to activate it.')
      end

      if error_message
        error = ActionController::TranslatedError.new(error_message)
        error.status = :unauthorized
        raise error
      end

      logger.info "Authenticated with token '#{token}'"
    end
  end

end
