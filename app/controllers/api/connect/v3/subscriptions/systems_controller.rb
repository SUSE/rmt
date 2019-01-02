class Api::Connect::V3::Subscriptions::SystemsController < Api::Connect::BaseController

  def announce_system
    @system = System.create!(hostname: params[:hostname], hw_info: HwInfo.new(hw_info_params))

    logger.info("System '#{@system.hostname}' announced")
    respond_with(@system, serializer: ::V3::SystemSerializer, location: nil)
  end

  private

  def hw_info_params
    return {} if params[:hwinfo].blank?
    params[:hwinfo].permit(:cpus, :sockets, :arch, :hypervisor, :uuid)
  end
end
