class RMT::CLI::Mirror < RMT::CLI::Base

  default_task :repos

  desc 'repos', 'Mirror enabled repositories'
  def repos
    repos = Repository.where(mirroring_enabled: true)
    if repos.empty?
      warn 'There are no repositories marked for mirroring.'
      return
    end
    repos.each { |repo| mirror(repo) }
  end

  desc 'custom URL', 'Mirror a custom repository URL'
  def custom(url, path = nil)
    url += '/' unless url.end_with?('/')
    path ||= Repository.make_local_path(url)

    RMT::Mirror.new(
      mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR,
      repository_url: url,
      local_path: path,
      mirror_src: Settings.mirroring.mirror_src,
      logger: Logger.new(STDOUT)
    ).mirror
  end

end
