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

  desc 'repository TARGETS', _('Mirror enabled repositories by given targets (SCC IDs or URLs)')
  long_desc <<~REPOS
    #{_('Mirror enabled repositories by given targets: SCC IDs or URLs.')}

    #{_('Examples')}:

    $ rmt-cli mirror repository 2526

    $ rmt-cli mirror repository https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/openSUSE_Tumbleweed/

    $ rmt-cli mirror repository 2526 https://download.opensuse.org/repositories/systemsmanagement:/SCC:/RMT/openSUSE_Tumbleweed/
  REPOS
  def repository(*targets)
    RMT::Lockfile.lock('mirror') do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger, mirror_src: RMT::Config.mirror_src_files?)

      targets = clean_target_input(targets)
      raise RMT::CLI::Error.new(_('No repository IDs supplied')) if targets.empty?

      repos = []
      targets.each do |target|
        repo = find_repo_by_target(target)
        raise RMT::CLI::Error.new(_('Mirroring of repository by target %{target} is not enabled') % { target: target }) unless repo.mirroring_enabled
        repos << repo
      rescue ActiveRecord::RecordNotFound
        raise RMT::CLI::Error.new(_('Repository by target %{target} not found') % { target: target })
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

  def find_repo_by_target(target)
    repository_id = Integer(target, 10) rescue nil

    if repository_id
      return Repository.find_by!(scc_id: repository_id)
    end

    Repository.find_by!(external_url: target)
  end

end
