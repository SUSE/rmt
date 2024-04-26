class Api::Connect::V3::Systems::SystemsController < Api::Connect::BaseController

  before_action :authenticate_system

  def update
    if params[:online_at].present?
      params[:online_at].each do |online_at|
        dthours = online_at.split(':')
        if dthours.count == 2
          online_day = online_at.split(':')[0]
          online_hours = online_at.split(':')[1]
          system_uptime = @system.system_uptimes.find_by(online_at_day: online_day)

          if system_uptime
            system_uptime.update!(online_at_hours: online_hours)
          else
            SystemUptime.create!(system_id: @system.id, online_at_day: online_day, online_at_hours: online_hours)
          end
        else
          logger.error(N_("Uptime data is malformed '%s'") % online_at)
        end
      end
    end

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
