class V3::ServiceSerializer < ApplicationSerializer

  attributes :id, :name, :url, :obsoleted_service_name, :product

  has_one :product, serializer: V3::ProductSerializer

  def url
    # credentials parameter is required by zypper and Yast
    # it specifies which file to use for storing credentials on the client
    service_url(object, host: base_url, credentials: object.name)
  end

  def obsoleted_service_name
    instance_options[:obsoleted_service_name] || ''
  end

end
