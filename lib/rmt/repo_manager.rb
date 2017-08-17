require 'rmt'
require 'thor'

# rubocop:disable Rails/Output

class RMT::RepoManager < Thor

  class << self
    # monkey patch for the output of the help command
    # (removes the alphabetical sorting and adds some custom behavior)
    def help(shell, subcommand = false)
      list = printable_commands(true, subcommand)
      Thor::Util.thor_classes_in(self).each do |klass|
        list += klass.printable_commands(false)
      end

      list.reject! {|l| l[0].split[1] == 'help'}

      if defined?(@package_name) && @package_name
        shell.say "#{@package_name} commands:"
      else
        shell.say "Commands:"
      end

      shell.print_table(list, :indent => 2, :truncate => true)
      shell.say
      class_options_help(shell)

      shell.say 'All commands can be run with -h (or --help) for more information.'
    end
  end

  desc 'list', 'List all repositories'
  option :all, type: :boolean
  def list
    scope = options[:all] ? :all : :enabled
    list_repositories(scope: scope)
  end

  desc 'enable TARGET', 'Enable a repository or product'
  option 'exclude-optional', aliases: '-x', default: true, type: :boolean
  def enable(target)
    repo_id = Integer(target, 10) rescue nil
    if repo_id
      change_repository_mirroring(true, repo_id)
    else
      identifier, version, arch = target.split('/')
      change_product_mirroring(true, identifier, version, arch, exclude_optional: options['exclude-optional'])
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

  desc 'version', 'Show version'
  def version
    puts RMT::VERSION
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

    products = Product.where(conditions).all
    products.each do |product|
      conditions = { mirroring_enabled: !mirroring_enabled } # to only update the repos which need change
      conditions[:enabled] = true if (options[:exclude_optional])
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
      rows << [ repository.id, repository.name, repository.description, repository.mirroring_enabled ]
    end

    puts Terminal::Table.new headings: %w[ID Name Description Mirror?], rows: rows
  end

end
