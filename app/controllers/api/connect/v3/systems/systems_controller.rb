class Api::Connect::V3::Systems::SystemsController < Api::Connect::BaseController

  before_action :authenticate_system

  def update
    @system.hostname = params[:hostname]

    # Since the payload is handled by rails all values are converted to string
    # e.g. cpus: 16 becomes cpus: "16". We save this as string for now and expect
    # SCC to handle the convertation correctly
    @system.system_information = hwinfo_params[:hwinfo].to_json

    if @system.save
      logger.info(N_("Updated system information for host '%s'") % @system.hostname)
    end

    respond_with(@system, serializer: ::V3::SystemSerializer)
  end

  def deregister
    respond_with(@system.destroy, serializer: ::V3::SystemSerializer)
  end

  private

  def hwinfo_params
    # Allow all attributes without validating the key structure
    # This is fine since the systems are only internal and RMT users
    # can save in their own database whatever they want.
    # When forwarded to SCC, SCC validates the payload for correctness.
    params.permit(hwinfo: {})
  end
end
