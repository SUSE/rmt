# rubocop:disable Rails/Output
class RMT::CLI::Mirror < RMT::CLI::Subcommand

  default_task :repos

  desc 'repos', 'Mirror enabled repositories', hide: true
  def repos
    RMT::CLI::Base.handle_exceptions { mirror }
  end

  desc 'custom URL', 'Mirror a custom repository URL'
  option :path, desc: 'Change local path (relative to your base_dir)' # TODO: what is this actually? better description!
  def custom(url)
    path = options.path || Repository.make_local_path(url)
    mirror_one_repo(url, path, base_dir)
  end

  no_commands do
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
          mirror_one_repo(repo_url, repository.local_path, base_dir, repository.auth_token)
          repository.refresh_timestamp!
        rescue RMT::Mirror::Exception => e
          warn e.to_s
        end
      end
    end

    def mirror_one_repo(repository_url, local_path, base_dir, auth_token = nil)
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

end
