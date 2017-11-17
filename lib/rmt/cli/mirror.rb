# rubocop:disable Rails/Output

module RMT::CLI::Mirror

  def self.mirror(repository_url = nil, local_path = nil)
    require 'rmt/mirror'
    require 'rmt/config'

    if repository_url
      local_path ||= Repository.make_local_path(repository_url)
      mirror_one_repo(repository_url, local_path)
      return
    end

    repositories = Repository.where(mirroring_enabled: true)

    if repositories.empty?
      warn 'There are no repositories marked for mirroring.'
      return
    end

    repositories.each do |repository|
      begin
        puts "Mirroring repository #{repository.name}"
        mirror_one_repo(repository.external_url, repository.local_path, repository.auth_token)
        repository.refresh_timestamp!
      rescue RMT::Mirror::Exception => e
        warn e.to_s
      end
    end
  rescue Interrupt
    raise RMT::CLI::Error, 'Interrupted.'
  end

  def self.mirror_one_repo(repository_url, local_path, auth_token = nil)
    RMT::Mirror.new(
      mirroring_base_dir: RMT::DEFAULT_MIRROR_DIR,
      mirror_src: Settings.mirroring.mirror_src,
      repository_url: repository_url,
      local_path: local_path,
      auth_token: auth_token,
      logger: Logger.new(STDOUT)
    ).mirror
  end

end
