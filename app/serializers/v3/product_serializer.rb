class V3::ProductSerializer < ApplicationSerializer

  def product_type
    object.product_type.to_s
  end

  def repositories
    object.repositories.map do |repository|
      V3::RepositorySerializer.new(repository, base_url: base_url)
    end
  end

  has_many :extensions, serializer: V3::ProductSerializer

  attributes :id, :name, :identifier, :former_identifier, :version, :release_type, :arch,
             :friendly_name, :product_class, :cpe, :free, :description, :eula_url, :repositories, :product_type, :extensions

  def arch
    (object.arch == 'unknown') ? nil : object.arch
  end

  def eula_url
    if object.eula_url
      uri = SUSE::Misc.uri_replace_hostname(object.eula_url, base_url)
      uri.to_s
    else
      ''
    end
  end

end
