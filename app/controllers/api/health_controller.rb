class Api::HealthController < ApplicationController

  def status
    render status: :ok, json: { state: 'online' }
  end

end
