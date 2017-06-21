class V3::RepositorySerializer < ActiveModel::Serializer

  attributes :id, :name, :url, :distro_target, :description, :enabled, :autorefresh

  def url
    uri = SUSE::Misc.uri_replace_hostname(object.external_url, @instance_options[:scheme], @instance_options[:host], @instance_options[:port])
    uri.to_s
  end

  def enabled
    if @instance_options[:enabled_repositories]
      @instance_options[:enabled_repositories].include? object.id
    else
      object.enabled
    end
  end

end
