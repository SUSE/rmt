class Api::Connect::V4::Systems::SystemsController < Api::Connect::V4::BaseController

  before_action :authenticate_system

  def update
    # FIXME: need hwinfo -- require_params([:hwinfo])

    @system.hostname = params[:hostname] || _('Not provided')
    # FIXME: @system.hw_info.update_attributes(hwinfo_params)

    if @system.save
      logger.info(N_("Updated system information for host '%s'") % @system.hostname)
    end

    respond_with(@system, serializer: ::V3::SystemSerializer)
  end

end
