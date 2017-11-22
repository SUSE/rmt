# rubocop:disable Rails/Output

module RMT::CLI::Mirror

  def self.mirror(repository_url = nil, local_path = nil, base_dir = nil, from_dir = nil, repo_ids = nil)
    require 'rmt/mirror'
    require 'rmt/config'

    base_dir = base_dir || RMT::DEFAULT_MIRROR_DIR

    if repository_url
      local_path ||= Repository.make_local_path(repository_url)
      mirror_one_repo(repository_url, local_path, nil, base_dir)
      return
    end

    repositories = if repo_ids
      Repository.find(repo_ids)
    else
      Repository.where(mirroring_enabled: true)
    end

    if repositories.empty?
      warn 'There are no repositories marked for mirroring.'
      return
    end

    repositories.each do |repository|
      begin
        puts "Mirroring repository #{repository.name}"
        repo_url = repository.external_url
        repo_url.sub!(/.*(?=SUSE)/, "file://#{from_dir}/") if from_dir
        mirror_one_repo(repo_url, repository.local_path, repository.auth_token, base_dir)
        repository.refresh_timestamp!
      rescue RMT::Mirror::Exception => e
        warn e.to_s
      end
    end
  end

  def self.mirror_one_repo(repository_url, local_path, auth_token = nil, base_dir)
    RMT::Mirror.new(
      mirroring_base_dir: base_dir,
      mirror_src: Settings.mirroring.mirror_src,
      repository_url: repository_url,
      local_path: local_path,
      auth_token: auth_token,
      logger: Logger.new(STDOUT)
    ).mirror
  end

end
