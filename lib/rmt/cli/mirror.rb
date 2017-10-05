module RMT::CLI::Mirror

  def self.mirror
    require 'rmt/mirror'
    require 'rmt/config'

    repositories = Repository.where(mirroring_enabled: true)

    if repositories.empty?
      warn 'There are no repositories marked for mirroring.'
      return
    end

    repositories.each do |repository|
      begin
        RMT::Mirror.new(
          mirroring_base_dir: Settings.mirroring.base_dir,
          mirror_src: Settings.mirroring.mirror_src,
          repository_url: repository.external_url,
          local_path: repository.local_path,
          auth_token: repository.auth_token,
          logger: Logger.new(STDOUT)
        ).mirror

        repository.refresh_timestamp!
      rescue RMT::Mirror::Exception => e
        warn e.to_s
      end
    end
  end

end
