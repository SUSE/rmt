module RMT::CLI::Mirror

  def self.mirror
    require 'rmt'
    require 'rmt/mirror'
    require 'rmt/config'

    Repository.where(mirroring_enabled: true).each do |repository|
      begin
        RMT::Mirror.new(
          mirroring_base_dir: Settings.mirroring.base_dir,
          mirror_src: Settings.mirroring.mirror_src,
          repository_url: repository.external_url,
          local_path: repository.local_path,
          auth_token: repository.auth_token,
          logger: Logger.new(STDOUT)
        ).mirror

        repository.last_mirrored_at = DateTime.now.utc
        repository.save!
      rescue RMT::Mirror::Exception => e
        warn e.to_s
      end
    end
  end

end
