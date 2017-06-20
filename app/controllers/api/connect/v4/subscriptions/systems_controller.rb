class Api::Connect::V4::Subscriptions::SystemsController < Api::Connect::V4::BaseController

  def announce_system
    system = System.create!(hostname: params[:hostname]) # TODO: store hwinfo data

    logger.info( "System '#{system.hostname}' announced" )
    respond_with( system, serializer: ::V3::SystemSerializer, location: nil )
  end

end
