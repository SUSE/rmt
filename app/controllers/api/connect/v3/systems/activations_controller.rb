class Api::Connect::V3::Systems::ActivationsController < Api::Connect::BaseController

  before_action :authenticate_system

  def index
    respond_with(@system.activations, each_serializer: ::V3::ActivationSerializer)
  end

end
