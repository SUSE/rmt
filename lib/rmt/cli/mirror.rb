class RMT::CLI::Mirror < RMT::CLI::Base
  desc 'all', _('Mirror all enabled repositories')
  def all
    RMT::Lockfile.lock('mirror') do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger, mirror_src: RMT::Config.mirror_src_files?)
      errors = []

      begin
        mirror.mirror_suma_product_tree(repository_url: 'https://scc.suse.com/suma/')
      rescue RMT::Mirror::Exception => e
        errors << _('Mirroring SUMA product tree failed: %{error_message}') % { error_message: e.message }
      end

      raise RMT::CLI::Error.new(_('There are no repositories marked for mirroring.')) if Repository.only_mirroring_enabled.empty?

      mirrored_repo_ids = []
      until (repos = Repository.only_mirroring_enabled.where.not(id: mirrored_repo_ids)).empty?
        repo_ids, repo_errors = mirror_repos!(mirror, repos)

        mirrored_repo_ids.concat(repo_ids)
        errors.concat(repo_errors)
      end

      handle_errors!(errors)
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

      _, repo_errors = mirror_repos!(mirror, repos)
      handle_errors!(repo_errors)
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
          product_repos = product.repositories.only_mirroring_enabled
          raise RMT::CLI::Error.new(_('Product %{target} has no repositories enabled') % { target: target }) if product_repos.empty?
          repos += product_repos.to_a
        end
      rescue ActiveRecord::RecordNotFound
        raise RMT::CLI::Error.new(_('Product with ID %{target} not found') % { target: target })
      end

      _, repo_errors = mirror_repos!(mirror, repos)
      handle_errors!(repo_errors)
    end
  end

  protected

  def mirror_repos!(mirror, repos)
    mirrored_repo_ids = []
    errors = []

    repos.each do |repo|
      mirror.mirror(
        repository_url: repo.external_url,
        local_path: Repository.make_local_path(repo.external_url),
        auth_token: repo.auth_token,
        repo_name: repo.name
      )
      repo.refresh_timestamp!
    rescue RMT::Mirror::Exception => e
      errors << _("Repository '%{repo_name}' (%{repo_id}): %{error_message}") % {
        repo_id: repo.id, repo_name: repo.name, error_message: e.message
      }
    ensure
      mirrored_repo_ids << repo.id
    end

    [mirrored_repo_ids, errors]
  end

  def handle_errors!(errors)
    return if errors.empty?

    raise RMT::CLI::Error.new(
      _('The following errors ocurred while mirroring:%{errors_list}') % {
        errors_list: "\n" + errors.join("\n")
      }
    )
  end
end
