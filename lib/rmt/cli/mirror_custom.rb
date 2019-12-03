class RMT::CLI::MirrorCustom < RMT::CLI::Base

  desc 'all', _('Mirror all enabled custom repositories')
  def all
    RMT::Lockfile.lock do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger, mirror_src: RMT::Config.mirror_src_files?)

      raise RMT::CLI::Error.new(_('There are no custom repositories marked for mirroring.')) if Repository.where(mirroring_enabled: true).empty?

      mirrored_repo_ids = []
      until Repository.where(mirroring_enabled: true).where.not(id: mirrored_repo_ids).blank?
        repo = Repository.where(mirroring_enabled: true).where.not(id: mirrored_repo_ids).first

        begin
          mirror_repo!(mirror, repo)
        rescue RMT::Mirror::Exception => e
          logger.warn e.to_s
        ensure
          mirrored_repo_ids << repo.id
        end
      end
    end
  end

  default_task :all

  desc 'repository IDS', _('Mirror enabled custom repositories with given repository IDs')
  def repository(*ids)
    RMT::Lockfile.lock do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger, mirror_src: RMT::Config.mirror_src_files?)

      ids = clean_target_input(ids)
      raise RMT::CLI::Error.new(_('No repository IDs supplied')) if ids.empty?

      repos = []
      ids.each do |id|
        repo = Repository.find_by!(id: id)
        raise RMT::CLI::Error.new(_('Mirroring of repository with ID %{repo_id} is not enabled') % { repo_id: id }) unless repo.mirroring_enabled
        repos << repo
      rescue ActiveRecord::RecordNotFound
        raise RMT::CLI::Error.new(_('Repository with ID %{repo_id} not found') % { repo_id: id })
      end

      repos.each do |repo|
        mirror_repo!(mirror, repo)
      rescue RMT::Mirror::Exception => e
        logger.warn e.to_s
      end
    end
  end

  protected

  def mirror_repo!(mirror, repo)
    mirror.mirror(
      repository_url: repo.external_url,
      local_path: Repository.make_local_path(repo.external_url),
      auth_token: repo.auth_token,
      repo_name: repo.name
    )

    repo.refresh_timestamp!
  end


end
