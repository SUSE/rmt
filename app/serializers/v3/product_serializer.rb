class V3::ProductSerializer < ActiveModel::Serializer
  def product_type
    object.product_type ? object.product_type : ''
  end

  attributes :id, :name, :identifier, :former_identifier, :version, :release_type, :arch,
             :friendly_name, :product_class, :cpe, :free, :description, :eula_url, :repositories, :product_type

  has_many :extensions, serializer: V3::ProductSerializer
  has_many :repositories,serializer: V3::RepositorySerializer

  def arch
    (object.arch == 'unknown') ? nil : object.arch
  end

  def eula_url
    object.eula_url || ''
  end

end
