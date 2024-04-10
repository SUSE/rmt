class RMT::CLI::Mirror < RMT::CLI::Base
  class_option :do_not_raise_unpublished, desc: _('Do not fail the command if product is in alpha or beta stage'), type: :boolean, required: false

  desc 'all', _('Mirror all enabled repositories')
  def all
    RMT::Lockfile.lock('mirror') do
      downloaded_files_count = 0
      downloaded_files_size = 0
      start_time = Time.current

      begin
        mirror.mirror_suma_product_tree(repository_url: 'https://scc.suse.com/suma/')
      rescue RMT::Mirror::Exception => e
        errors << _('Mirroring SUMA product tree failed: %{error_message}') % { error_message: e.message }
      end

      raise RMT::CLI::Error.new(_('There are no repositories marked for mirroring.')) if Repository.only_mirroring_enabled.empty?

      # The set of repositories to be mirrored can change while the command is
      # mirroring. Hence, the iteration uses a until loop to ensure no
      # repositories have been left unmirrored. The ActiveRecord::Relation is
      # loaded before being used to avoid querying twice in the block, which
      # could lead to different Repositories sets where it's used.
      mirrored_repo_ids = []
      until (repos = Repository.only_mirroring_enabled.where.not(id: mirrored_repo_ids).load).empty?

        files_count, files_size = mirror_repos!(repos)

        downloaded_files_count += files_count
        downloaded_files_size += files_size

        mirrored_repo_ids.concat(repos.pluck(:id))
      end

      finish_execution(
        start_time: start_time,
        repo_count: mirrored_repo_ids.count,
        downloaded_files_count: downloaded_files_count,
        downloaded_files_size: downloaded_files_size
      )
    end
  end

  default_task :all


  desc 'repository IDS', _('Mirror enabled repositories with given repository IDs')
  def repository(*ids)
    RMT::Lockfile.lock('mirror') do
      start_time = Time.current

      ids = clean_target_input(ids)
      raise RMT::CLI::Error.new(_('No repository IDs supplied')) if ids.empty?

      repos = ids.map do |id|
        repo = Repository.find_by(friendly_id: id)
        errored_repos_id << id if options[:do_not_raise_unpublished] && repo.nil?
        errors << _('Repository with ID %{repo_id} not found') % { repo_id: id } if repo.nil?
        repo
      end

      downloaded_files_count, downloaded_files_size = mirror_repos!(repos)

      finish_execution(
        start_time: start_time,
        repo_count: repos.count,
        downloaded_files_count: downloaded_files_count,
        downloaded_files_size: downloaded_files_size
      )
    end
  end

  desc 'product IDS', _('Mirror enabled repositories for a product with given product IDs')
  def product(*targets)
    RMT::Lockfile.lock('mirror') do
      start_time = Time.current

      targets = clean_target_input(targets)
      raise RMT::CLI::Error.new(_('No product IDs supplied')) if targets.empty?

      repos = []
      targets.each do |target|
        products = Product.get_by_target!(target)
        errors << _('Product for target %{target} not found') % { target: target } if products.empty?
        products.each do |product|
          product_repos = product.repositories.only_mirroring_enabled
          if product_repos.empty?
            errors << _('Product %{target} has no repositories enabled') % { target: target }
            errored_products_id << target if options[:do_not_raise_unpublished]
          end
          repos += product_repos.to_a
        end
      rescue ActiveRecord::RecordNotFound
        errors << _('Product with ID %{target} not found') % { target: target }
        errored_products_id << target if options[:do_not_raise_unpublished]
      end

      downloaded_files_count, downloaded_files_size = mirror_repos!(repos)

      finish_execution(
        start_time: start_time,
        repo_count: repos.count,
        downloaded_files_count: downloaded_files_count,
        downloaded_files_size: downloaded_files_size
      )
    end
  end

  protected

  def mirror
    @mirror ||= RMT::Mirror.new(logger: logger, mirror_src: RMT::Config.mirror_src_files?)
  end

  def errors
    @errors ||= []
  end

  def errored_repos_id
    @errored_repos_id ||= []
  end

  def errored_products_id
    @errored_products_id ||= []
  end

  def in_alpha_or_beta?
    products = []
    unless errored_repos_id.empty?
      products = Product.joins(:repositories).where(
        'repositories.id' => errored_repos_id
      )
    end
    unless errored_products_id.empty?
      products = Product.where(id: errored_products_id)
    end
    return false if products.empty?

    ignore_stages = ['alpha', 'beta']
    products.each do |product|
      if product.base?
        return false unless ignore_stages.include? product.release_stage
      else
        root_products = Product.where(id: product.root_products.ids)
        root_products.each do |root_product|
          if root_product.base?
            return false unless ignore_stages.include? root_product.release_stage
          end
        end
      end
    end
    # if not empty means there is missing info because of alpha/beta
    true
  end

  def mirror_repos!(repos)
    downloaded_files_count = 0
    downloaded_files_size = 0

    repos.compact.each do |repo|
      unless repo.mirroring_enabled
        errors << _('Mirroring of repository with ID %{repo_id} is not enabled') % { repo_id: repo.friendly_id }
        next
      end

      files_count, files_size = mirror.mirror(
        repository_url: repo.external_url,
        local_path: Repository.make_local_path(repo.external_url),
        auth_token: repo.auth_token,
        repo_name: repo.name
      )
      repo.refresh_timestamp!

      downloaded_files_count += files_count if files_count
      downloaded_files_size += files_size if files_size
    rescue RMT::Mirror::Exception => e
      errors << _("Repository '%{repo_name}' (%{repo_id}): %{error_message}") % {
        repo_id: repo.friendly_id, repo_name: repo.name, error_message: e.message
      }
      errored_repos_id << repo.id if options[:do_not_raise_unpublished]
    end

    [downloaded_files_count, downloaded_files_size]
  end

  def finish_execution(start_time:, repo_count:, downloaded_files_count:, downloaded_files_size:)
    if errors.empty?
      logger.info("\e[32m" + _('Total mirrored repositories: %{repo_count}') % { repo_count: repo_count } + "\e[0m")
      logger.info("\e[32m" + _('Total transferred files: %{files_count}') % { files_count: downloaded_files_count } + "\e[0m")
      logger.info("\e[32m" + _('Total transferred file size: %{files_size} MB') % { files_size: files_size_format(downloaded_files_size) } + "\e[0m")
      logger.info("\e[32m" + _('Total Mirror Time: %{time}') % { time: format_time(start_time) } + "\e[0m")
      logger.info("\e[32m" + _('Mirroring complete.') + "\e[0m")
    else
      logger.warn("\e[31m" + _('The following errors occurred while mirroring:') + "\e[0m")
      errors.each { |e| logger.warn("\e[31m" + (e.end_with?('.') ? e : e + '.') + "\e[0m") }
      logger.warn("\e[33m" + _('Mirroring completed with errors.') + "\e[0m")
      raise RMT::CLI::Error.new('The command exited with errors.') unless options[:do_not_raise_unpublished] && in_alpha_or_beta?
    end
  end

  def files_size_format(downloaded_files_size)
    (downloaded_files_size / 1024000.0).floor(2)
  end

  def format_time(start_time)
    finish_time = Time.current - start_time

    hours, remainder = finish_time.divmod(3600)
    minutes, seconds = remainder.divmod(60)

    '%02d:%02d:%02d' % [hours, minutes, seconds]
  end
end
