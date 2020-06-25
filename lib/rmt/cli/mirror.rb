class RMT::CLI::Mirror < RMT::CLI::Base
  desc 'all', _('Mirror all enabled repositories')
  def all
    RMT::Lockfile.lock('mirror') do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger, mirror_src: RMT::Config.mirror_src_files?)

      begin
        mirror.mirror_suma_product_tree(repository_url: 'https://scc.suse.com/suma/')
      rescue RMT::Mirror::Exception => e
        logger.warn(e.message)
      end

      raise RMT::CLI::Error.new(_('There are no repositories marked for mirroring.')) if Repository.where(mirroring_enabled: true).empty?

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

  desc 'repository IDS', _('Mirror enabled repositories with given repository IDs')
  def repository(*ids)
    RMT::Lockfile.lock('mirror') do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger, mirror_src: RMT::Config.mirror_src_files?)

      ids = clean_target_input(ids)
      raise RMT::CLI::Error.new(_('No repository IDs supplied')) if ids.empty?

      repos = []
      ids.each do |id|
        repo = Repository.find_by!(scc_id: id)
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

  desc 'product IDS', _('Mirror enabled repositories for a product with given product IDs')
  def product(*targets)
    RMT::Lockfile.lock('mirror') do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger, mirror_src: RMT::Config.mirror_src_files?)

      targets = clean_target_input(targets)
      raise RMT::CLI::Error.new(_('No product IDs supplied')) if targets.empty?

      repos = []
      targets.each do |target|
        products = Product.get_by_target!(target)
        raise RMT::CLI::Error.new(_('Product for target %{target} not found') % { target: target }) if products.empty?
        products.each do |product|
          product_repos = product.repositories.where(mirroring_enabled: true)
          raise RMT::CLI::Error.new(_('Product %{target} has no repositories enabled') % { target: target }) if product_repos.empty?
          repos += product_repos.to_a
        end
      rescue ActiveRecord::RecordNotFound
        raise RMT::CLI::Error.new(_('Product with ID %{target} not found') % { target: target })
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
