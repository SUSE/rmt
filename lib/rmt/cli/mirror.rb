# rubocop:disable Rails/Output
class RMT::CLI::Mirror < RMT::CLI::Base

  default_task :repos

  desc 'repos', 'Mirror enabled repositories'
  def repos
    require 'rmt/mirror'
    require 'rmt/config'

    repos = Repository.where(mirroring_enabled: true)
    if repos.empty?
      warn 'There are no repositories marked for mirroring.'
      return
    end

    base_dir = RMT::DEFAULT_MIRROR_DIR

    repos.each do |repository|
      begin
        puts "Mirroring repository #{repository.name} to #{base_dir}"
        RMT::Mirror.from_repo_model(repository, base_dir).mirror
        repository.refresh_timestamp!
      rescue RMT::Mirror::Exception => e
        warn e.to_s
      end
    end
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
