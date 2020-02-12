class Api::Connect::V3::Systems::SystemsController < Api::Connect::BaseController

  before_action :authenticate_system

  def update
    @system.hostname = params[:hostname] || _('Not provided')
    HwInfo.find_or_initialize_by(system_id: @system.id).update!(hw_info_params)

    if @system.save
      logger.info(N_("Updated system information for host '%s'") % @system.hostname)
    end

    respond_with(@system, serializer: ::V3::SystemSerializer)
  end

  def deregister
    respond_with(@system.destroy, serializer: ::V3::SystemSerializer)
  end

  private

  def hw_info_params
    params.require(:hwinfo).permit(:cpus, :sockets, :arch, :hypervisor, :uuid, :cloud_provider)
  end
end
