require 'rmt'
require 'rmt/cli'

# rubocop:disable Rails/Output

class RMT::RepoManager < RMT::Thor

  desc 'list', 'List all repositories'
  option :all, aliases: '-a', type: :boolean
  def list
    scope = options[:all] ? :all : :enabled
    list_repositories(scope: scope)
  end

  desc 'enable TARGET', 'Enable a repository or product'
  option 'include-non-mandatory', aliases: '-i', type: :boolean
  def enable(target)
    repo_id = Integer(target, 10) rescue nil
    if repo_id
      change_repository_mirroring(true, repo_id)
    else
      identifier, version, arch = target.split('/')
      change_product_mirroring(true, identifier, version, arch, include_non_mandatory: options['include-non-mandatory'])
    end
  end

  desc 'disable TARGET', 'Disable a repository or product'
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

  def change_product_mirroring(mirroring_enabled, identifier, version, arch, options = {})
    conditions = { identifier: identifier, version: version }
    conditions[:arch] = arch if arch
    repo_count = 0
    non_mandatory_count = 0

    products = Product.where(conditions).all
    products.each do |product|
      conditions = { mirroring_enabled: !mirroring_enabled } # to only update the repos which need change
      conditions[:enabled] = true if (mirroring_enabled && !options[:include_non_mandatory])
      repo_count += product.repositories.where(conditions).update_all(mirroring_enabled: mirroring_enabled)

      unless (options[:include_non_mandatory])
        non_mandatory_count += product.repositories.where(conditions.merge(enabled: false)).count
      end
    end
    puts "#{repo_count} repo(s) successfully #{mirroring_enabled ? 'enabled' : 'disabled'}."
    if (non_mandatory_count > 0)
      puts "#{non_mandatory_count} non-mandatory repos were not enabled. Use -i (--include-non-mandatory) flag to enable them."
    end
  end

  def list_repositories(scope: :enabled)
    conditions = {}
    conditions[:mirroring_enabled] = true unless (scope == :all)

    rows = []
    repositories = Repository.where(conditions)
    repositories.all.each do |repository|
      rows << [ repository.id, repository.name, repository.description, repository.mirroring_enabled ]
    end

    puts Terminal::Table.new headings: %w[ID Name Description Mirror?], rows: rows
  end

end
