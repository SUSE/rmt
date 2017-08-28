class Api::HealthController < ApplicationController

  def status
    render status: 200, json: { state: 'online' }
  end

end
