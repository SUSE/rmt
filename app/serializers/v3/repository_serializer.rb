class V3::RepositorySerializer < ApplicationSerializer

  attributes :id, :name, :url, :distro_target, :description, :enabled, :autorefresh

  def url
    uri = SUSE::Misc.uri_replace_hostname(object.external_url, base_url)
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
