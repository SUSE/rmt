# rubocop:disable Rails/Output

require 'rmt/cli/repos'

class RMT::CLI::Products < RMT::CLI::Base

  desc 'list', 'List all products'
  option :release_stage, aliases: '-r', type: :string, desc: 'beta, released'
  def list
    attributes = %i[id name version arch product_string release_stage mirror? last_mirrored_at]
    headings = ['ID', 'Name', 'Version', 'Architecture', 'Product string', 'Release stage', 'Mirror?', 'Last mirrored']

    rows = Product.with_release_stage(options[:release_stage]).map do |product|
      attributes.map { |a| product.public_send(a) }
    end

    if rows.empty?
      warn 'No products found in the DB. Please run "rmt-cli scc sync" to synchronize with SUSE Customer Center first.'
    else
      puts Terminal::Table.new headings: headings, rows: rows
    end
  end

  desc 'enable', 'Enable mirroring of product repositories by product ID or product string'
  def enable(target)
    change_product(target, true)
  end

  desc 'disable', 'Disable mirroring of product repositories by product ID or product string'
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
