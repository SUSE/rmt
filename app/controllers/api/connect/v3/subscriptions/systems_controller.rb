class Api::Connect::V3::Subscriptions::SystemsController < Api::Connect::BaseController

  def announce_system
    @system = System.create!(
      hostname: params[:hostname],
      system_information: info_params(key: :hwinfo)[:hwinfo].to_json,
      data_profiles: info_params(key: :data_profiles)[:data_profiles].to_h
    )

    logger.info("System '#{@system.hostname}' announced")
    respond_with(@system, serializer: ::V3::SystemSerializer, location: nil)
  end

  private

  def info_params(key:)
    # Allow all attributes without validating the key structure
    # This is fine since the systems are only internal and RMT users
    # can save in their own database whatever they want.
    # When forwarded to SCC, SCC validates the payload for correctness.
    permit_args = { key => {} }
    params.permit(permit_args)
  end
end
