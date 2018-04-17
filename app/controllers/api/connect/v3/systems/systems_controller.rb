class Api::Connect::V3::Systems::SystemsController < Api::Connect::BaseController

  before_action :authenticate_system

  def update
    @system.hostname = params[:hostname] || _('Not provided')
    if @system.hw_info.present?
      @system.hw_info.update(hwinfo_params)
    else
      @system.hw_info_attributes = hwinfo_params
    end

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
    params.require(:hwinfo).permit(:cpus, :sockets, :arch, :hypervisor, :uuid)
  end
end
