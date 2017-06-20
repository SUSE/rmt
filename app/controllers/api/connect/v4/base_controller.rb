class Api::Connect::V4::BaseController < ApplicationController
  respond_to :json

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

    raise ActionController::ParameterMissingTranslated.new(*missing_keys) if missing_keys.present?
  end

end
