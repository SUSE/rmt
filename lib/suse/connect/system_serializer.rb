require 'active_model_serializers'

# Serializes a system to be consumed by the SCC Api
class SUSE::Connect::SystemSerializer < ActiveModel::Serializer
  # RMT has two modes of sending system information to SCC
  # 1) Full update mode
  #    When a system is changed or new RMT will send the full system
  #    information available to SCC.
  # 2) Keepalive mode (:needs_full_update?)
  #    Since the keepalive mechanism has been released in SUSEConnect
  #    RMT also sends system information to SCC (e.g. last_seen_at).
  #    This saves resouces since not the full system information needs
  #    to be processed.
  attributes :login, :password, :last_seen_at, :created_at

  attribute :system_token, if: :has_system_token?

  attribute :hostname, if: :needs_full_update?
  attribute :hwinfo, if: :has_hwinfo_and_needs_full_update?
  attribute :products, if: :needs_full_update?
  attribute :online_at, if: :has_system_uptime?
  attribute :system_profiles, if: :has_system_profiles?

  # Define an initialize() method that overrides the inherited one,
  # calling it appropriately, and then sets up @serialized_profiles
  # with the optionally provided one.
  def initialize(system, options = {})
    # call inherited initialize() first
    super(system, options)

    # setup @serialized_profiles based upon provided options value,
    # if any, otherwise default to a new empty set.
    @serialized_profiles = (options || {}).fetch(:serialized_profiles, Set.new)
  end

  # We send the internal system id as system_token if the system (in RMT) is
  # duplicated (therefore using the system_token mechanism).
  # SCC needs a stable identifier as system_token to uniquly identify duplicated
  # systems behind proxies.
  # More info: https://github.com/SUSE/scc-docs/blob/master/rfc/0031_system_token.md
  def system_token
    object.id
  end

  def products
    object.activations.map do |activation|
      product = activation.product
      payload = {
        id: product.id,
        identifier: product.identifier,
        version: product.version,
        arch: product.arch,
        activated_at: activation.created_at
      }

      if activation.subscription
        payload[:regcode] = activation.subscription.regcode
      end

      payload
    end
  end

  def online_at
    object.system_uptimes.map do |system_uptime|
      payload = {
        online_at_day: system_uptime.online_at_day,
        online_at_hours: system_uptime.online_at_hours
      }
      payload
    end
  end

  def hwinfo
    JSON.parse(object.system_information).symbolize_keys
  end

  def has_hwinfo_and_needs_full_update?
    object.system_information.present? && needs_full_update?
  end

  def has_system_token?
    object.system_token.present?
  end

  def has_system_uptime?
    online_at.present?
  end

  def needs_full_update?
    !object.scc_synced_at
  end

  def system_profiles
    object.profiles.each_with_object({}) do |profile, hash|
      hash.merge!(
        profile.as_payload(
          include_data: include_profile_data?(profile)
        )
      )
    end
  end

  def include_profile_data?(profile)
    # Check if this profile has previously been included in the
    # serialized payload, and return a boolean indicating whether
    # to include the data field or not.
    if @serialized_profiles.include?(profile.id)
      false
    else
      @serialized_profiles.add(profile.id)
      true
    end
  end

  def has_system_profiles?
    object.profiles.present?
  end
end
