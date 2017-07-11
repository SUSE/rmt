class V3::ActivationSerializer < ApplicationSerializer

  attributes :id, :system_id, :service

  has_one :service, serializer: V3::ServiceSerializer

end
