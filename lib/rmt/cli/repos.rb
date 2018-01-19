class RMT::CLI::Repos < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'custom', 'List and modify custom repositories'
  subcommand 'custom', RMT::CLI::CustomRepos

  desc 'list', 'List repositories which are marked to be mirrored'
  option :all, aliases: '-a', type: :boolean, desc: 'List all repositories, including ones which are not marked to be mirrored'
  def list
    scope = options[:all] ? :all : :enabled
    list_repositories(scope: scope)
  end
  map ls: :list

  desc 'enable TARGET', 'Enable mirroring of repositories by repository ID or product string'
  def enable(target)
    change_repository_mirroring(target, true)
  end

  desc 'disable TARGET', 'Disable mirroring of repositories by repository ID or product string'
  def disable(target)
    change_repository_mirroring(target, false)
  end

  no_commands do
    def self.change_product_mirroring(mirroring_enabled, identifier, version, arch)
      conditions = { identifier: identifier, version: version }
      conditions[:arch] = arch if arch
      repo_count = 0

      products = Product.where(conditions).all
      products.each do |product|
        conditions = { mirroring_enabled: !mirroring_enabled } # to only update the repos which need change
        conditions[:enabled] = true if mirroring_enabled
        repo_count += product.change_repositories_mirroring!(conditions, mirroring_enabled)
      end

      raise RMT::CLI::Error, 'No repositories were modified.' unless (repo_count > 0)

      puts "#{repo_count} repo(s) successfully #{mirroring_enabled ? 'enabled' : 'disabled'}."
    end
  end

  protected

  def change_repository_mirroring(target, mirroring_enabled)
    repo_id = Integer(target, 10) rescue nil
    if repo_id
      # FIXME: A non-existing Id raises an ActiveRecord::RecordNotFound! Same for `products enable 123`
      Repository.by_id(repo_id).change_mirroring!(mirroring_enabled)
      puts "Repository successfully #{mirroring_enabled ? 'enabled' : 'disabled'}."
    else
      identifier, version, arch = target.split('/')
      self.class.change_product_mirroring(mirroring_enabled, identifier, version, arch)
    end
  end

  def list_repositories(scope: :enabled)
    repositories = (scope == :all) ? Repository.only_scc : Repository.only_scc.only_mirrored

    if repositories.empty?
      if options.all
        warn 'Run "rmt-cli sync" to synchronize with your SUSE Customer Center data first.'
      else
        warn 'No repositories enabled.'
      end
    else
      puts array_to_table(repositories, {
        scc_id: 'SCC ID',
        name: 'Name',
        description: 'Description',
        enabled: 'Mandatory?',
        mirroring_enabled: 'Mirror?',
        last_mirrored_at: 'Last mirrored'
      })
    end
  end

end
