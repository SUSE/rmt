class V3::ServiceSerializer < ActiveModel::Serializer

  include Rails.application.routes.url_helpers

  attributes :id, :name, :url, :obsoleted_service_name

  has_one :product, serializer: V3::ProductSerializer

  def url
    @instance_options[:service_url]
  end

  def obsoleted_service_name
    @instance_options[:obsoleted_service_name] || ''
  end

end
