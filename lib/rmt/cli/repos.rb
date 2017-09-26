# rubocop:disable Rails/Output

class RMT::CLI::Repos < RMT::CLI::Base

  desc 'list', 'List repositories which are marked to be mirrored'
  option :all, aliases: '-a', type: :boolean, desc: 'List all repositories, including ones which are not marked to be mirrored'
  def list
    scope = options[:all] ? :all : :enabled
    list_repositories(scope: scope)
  end

  desc 'enable TARGET', 'Enable mirroring of repositories by repository ID or product string'
  def enable(target)
    repo_id = Integer(target, 10) rescue nil
    if repo_id
      change_repository_mirroring(true, repo_id)
    else
      identifier, version, arch = target.split('/')
      change_product_mirroring(true, identifier, version, arch)
    end
  end

  desc 'disable TARGET', 'Disable mirroring of repositories by repository ID or product string'
  def disable(target)
    repo_id = Integer(target, 10) rescue nil
    if repo_id
      change_repository_mirroring(false, repo_id)
    else
      identifier, version, arch = target.split('/')
      change_product_mirroring(false, identifier, version, arch)
    end
  end

  protected

  def change_repository_mirroring(mirroring_enabled, repository_id)
    repository = Repository.find(repository_id)
    repository.mirroring_enabled = mirroring_enabled
    repository.save!
    puts "Repo successfully #{mirroring_enabled ? 'enabled' : 'disabled'}."
  end

  def change_product_mirroring(mirroring_enabled, identifier, version, arch)
    conditions = { identifier: identifier, version: version }
    conditions[:arch] = arch if arch
    repo_count = 0

    products = Product.where(conditions).all
    products.each do |product|
      conditions = { mirroring_enabled: !mirroring_enabled } # to only update the repos which need change
      conditions[:enabled] = true if mirroring_enabled
      repo_count += product.repositories.where(conditions).update_all(mirroring_enabled: mirroring_enabled)
    end
    puts "#{repo_count} repo(s) successfully #{mirroring_enabled ? 'enabled' : 'disabled'}."
  end

  def list_repositories(scope: :enabled)
    conditions = {}
    conditions[:mirroring_enabled] = true unless (scope == :all)

    rows = []
    repositories = Repository.where(conditions)
    repositories.all.each do |repository|
      rows << [
        repository.id,
        repository.name,
        repository.description,
        repository.enabled,
        repository.mirroring_enabled,
        repository.last_mirrored_at
      ]
    end

    puts Terminal::Table.new headings: ['ID', 'Name', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored'], rows: rows
  end

end
