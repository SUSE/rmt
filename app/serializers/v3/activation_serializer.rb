class V3::ActivationSerializer < ApplicationSerializer

  attributes :id, :system_id, :service
  attributes :regcode, :name, :status, :starts_at, :expires_at, :type

  %i[regcode name status starts_at expires_at].each do |name|
    define_method(name) do
      object.try(:subscription).try(name)
    end
  end

  def type
    object.try(:subscription).try(:kind)
  end

  has_one :service, serializer: V3::ServiceSerializer
end
