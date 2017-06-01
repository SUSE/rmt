class Api::Connect::V4::Subscriptions::SystemsController < ApplicationController
  respond_to :json

  def announce_system
    render json: { username: 'SCC_potato', password: 'potato' }
  end
end
