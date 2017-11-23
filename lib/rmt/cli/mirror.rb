# rubocop:disable Rails/Output
class RMT::CLI::Mirror < RMT::CLI::Subcommand

  default_task :repos

  desc 'repos', 'Mirror enabled repositories (default)', hide: true
  long_desc "By default, mirrors the enabled online repositories.\nIf the RMT is in offline mode, it mirrors from the configured local path instead."
  def repos
    RMT::CLI::Base.handle_exceptions do
      if Settings.airgap.offline
        mirror(from_dir: airgap_path)
      else
        mirror
      end
    end
  end

  desc 'airgap', 'Mirror repos to mounted Airgap storage'
  def airgap
    repos_file = File.join(airgap_path, 'repos.json')
    repos_ids = JSON.parse(File.read(repos_file))
    repos = Repository.find(repos_ids)
    mirror(base_dir: airgap_path, repos: repos)
  end

  desc 'custom URL', 'Mirror a custom repository URL'
  option :path, desc: 'Change local path (relative to your base_dir)' # TODO: what is this actually? better description!
  def custom(url)
    path = options.path || Repository.make_local_path(url)
    mirror_one_repo(url, path, nil, base_dir) # TODO: who owns the base_dir?
  end

  private

  def base_dir

  end

  def mirror(base_dir: nil, from_dir: nil, repos: Repository.where(mirroring_enabled: true))
    require 'rmt/mirror'
    require 'rmt/config'

    base_dir ||= RMT::DEFAULT_MIRROR_DIR

    if repos.empty?
      warn 'There are no repositories marked for mirroring.'
      return
    end

    repos.each do |repository|
      begin
        puts "Mirroring repository #{repository.name} from #{from_dir || 'SCC'} to #{base_dir}"
        repo_url = repository.external_url
        repo_url.sub!(/.*(?=SUSE)/, "file://#{from_dir}/") if from_dir
        mirror_one_repo(repo_url, repository.local_path, repository.auth_token, base_dir)
        repository.refresh_timestamp!
      rescue RMT::Mirror::Exception => e
        warn e.to_s
      end
    end
  end

  def mirror_one_repo(repository_url, local_path, auth_token = nil, base_dir)
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
