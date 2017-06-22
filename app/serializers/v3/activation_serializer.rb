class V3::ActivationSerializer < ActiveModel::Serializer

  attributes :id, :system_id, :service

  has_one :service, serializer: V3::ServiceSerializer

end
