xml.repoindex(ttl: 86400) do # FIXME: config file for the options
  @repos.each do |repo|
    uri = SUSE::Misc.uri_replace_hostname(repo.external_url, request.scheme, request.host, request.port)

    attributes = {
      url: uri.to_s,
      alias: repo.name,
      name: repo.name,
      autorefresh: repo.autorefresh,
      enabled: repo.enabled
    }

    attributes[:distro_target] = repo.distro_target if repo.distro_target
    xml.repo attributes
  end
end
