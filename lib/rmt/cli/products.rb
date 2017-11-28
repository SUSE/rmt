# rubocop:disable Rails/Output

require 'rmt/cli/repos'

class RMT::CLI::Products < RMT::CLI::Subcommand

  default_task :list

  desc 'list', 'List products which are marked to be mirrored.', hide: true
  option :all, aliases: '-a', type: :boolean, desc: 'List all products, including ones which are not marked to be mirrored'
  option :release_stage, aliases: '-r', type: :string, desc: 'beta, released'
  def list
    attributes = %i[id name version arch product_string release_stage mirror? last_mirrored_at]
    headings = ['ID', 'Name', 'Version', 'Architecture', 'Product string', 'Release stage', 'Mirror?', 'Last mirrored']

    products = options.all ? Product.all : Product.mirrored

    rows = products.with_release_stage(options[:release_stage]).map do |product|
      attributes.map { |a| product.public_send(a) }
    end

    if rows.empty?
      warn 'No matching products found in the database.'
      puts 'Run "rmt-cli scc sync" to synchronize with your SUSE Customer Center data first.' if options.all
    else
      puts Terminal::Table.new headings: headings, rows: rows
    end
    puts 'Only enabled products are shown by default. Use the `--all` option to see all products.' unless options.all
  end

  desc 'enable', 'Enable mirroring of product repositories by product ID or product string.'
  def enable(target)
    change_product(target, true)
  end

  desc 'disable', 'Disable mirroring of product repositories by product ID or product string.'
  def disable(target)
    change_product(target, false)
  end

  protected

  def change_product(target, set_enabled)
    repo_id = Integer(target, 10) rescue nil
    if repo_id
      change_product_mirroring_by_id(repo_id, set_enabled)
    else
      identifier, version, arch = target.split('/')
      RMT::CLI::Repos.change_product_mirroring(set_enabled, identifier, version, arch)
    end
  end

  def change_product_mirroring_by_id(id, mirroring_enabled)
    conditions = { mirroring_enabled: !mirroring_enabled } # to only update the repos which need change
    conditions[:enabled] = true if mirroring_enabled

    repo_count = Product.find(id).change_repositories_mirroring!(conditions, mirroring_enabled)

    raise RMT::CLI::Error, 'No repositories were modified.' unless (repo_count > 0)

    puts "#{repo_count} repo(s) successfully #{mirroring_enabled ? 'enabled' : 'disabled'}."
  end

end
