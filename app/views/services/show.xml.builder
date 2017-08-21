xml.repoindex(ttl: 86400) do # FIXME: config file for the options
  @repos.each do |repo|
    attributes = {
      url: RMT::Misc.make_repo_url(@base_url, repo.local_path),
      alias: repo.name,
      name: repo.name,
      autorefresh: repo.autorefresh,
      enabled: repo.enabled
    }

    xml.repo attributes
  end
end
