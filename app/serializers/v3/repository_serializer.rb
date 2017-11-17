class V3::RepositorySerializer < ApplicationSerializer

  attributes :id, :name, :url, :description, :enabled, :autorefresh

  def url
    RMT::Misc.make_repo_url(base_url, object.local_path)
  end

end
