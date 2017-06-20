class V3::RepositorySerializer < ActiveModel::Serializer
  attributes :id, :url, :name, :distro_target, :description, :enabled, :autorefresh

  def enabled
    if @instance_options[:enabled_repositories]
      @instance_options[:enabled_repositories].include? object.id
    else
      object.enabled
    end
  end
end
