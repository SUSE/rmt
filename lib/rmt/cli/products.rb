# rubocop:disable Rails/Output

require 'rmt/cli/repos'

class RMT::CLI::Products < RMT::CLI::Base

  desc 'list', 'List all products'
  option :release_stage, aliases: '-r', type: :string, desc: 'beta, released'
  def list
    attributes = %i[id name version arch product_string release_stage mirror? last_mirrored_at]
    headings = ['ID', 'Name', 'Version', 'Architecture', 'Product string', 'Release stage', 'Mirror?']

    conditions = options[:release_stage] ? { release_stage: options[:release_stage] } : {}

    rows = Product.where(conditions).map do |product|
      attributes.map { |a| product.public_send(a) }
    end

    puts Terminal::Table.new headings: headings, rows: rows
  end

  desc 'enable', 'Enable mirroring of product repositories by product ID or product string'
  def enable(target)
    repo_id = Integer(target, 10) rescue nil
    if repo_id
      change_product_mirroring_by_id(repo_id, true)
    else
      identifier, version, arch = target.split('/')
      RMT::CLI::Repos.change_product_mirroring(true, identifier, version, arch)
    end
  end

  desc 'disable', 'Disable mirroring of product repositories by product ID or product string'
  def disable(target)
    repo_id = Integer(target, 10) rescue nil
    if repo_id
      change_product_mirroring_by_id(repo_id, false)
    else
      identifier, version, arch = target.split('/')
      RMT::CLI::Repos.change_product_mirroring(false, identifier, version, arch)
    end
  end

  protected

  def change_product_mirroring_by_id(id, mirroring_enabled)
    conditions = { mirroring_enabled: !mirroring_enabled } # to only update the repos which need change
    conditions[:enabled] = true if mirroring_enabled

    product = Product.find(id)
    repo_count = product.repositories.where(conditions).update_all(mirroring_enabled: mirroring_enabled)

    raise RMT::CLI::Error, 'No repositories were modified.' unless (repo_count > 0)

    puts "#{repo_count} repo(s) successfully #{mirroring_enabled ? 'enabled' : 'disabled'}."
  end

end
