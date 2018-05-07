require 'csv'
require 'terminal-table'

require 'rmt/cli/repos'

class RMT::CLI::Products < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'list', 'List products which are marked to be mirrored.'
  option :all, aliases: '-a', type: :boolean, desc: 'List all products, including ones which are not marked to be mirrored'
  option :release_stage, aliases: '-r', type: :string, desc: 'beta, released'
  option :csv, type: :boolean, desc: 'Output data in CSV format'

  def list
    attributes = %i[id name version arch product_string release_stage mirror? last_mirrored_at]
    headings = ['ID', 'Name', 'Version', 'Architecture', 'Product string', 'Release stage', 'Mirror?', 'Last mirrored']

    products = options.all ? Product.all : Product.mirrored
    rows = products.with_release_stage(options[:release_stage]).map do |product|
      attributes.map { |a| product.public_send(a) }
    end

    if rows.empty?
      if options.all
        warn 'Run "rmt-cli sync" to synchronize with your SUSE Customer Center data first.'
      else
        warn 'No matching products found in the database.'
      end
    else
      if options.csv
        puts array_to_csv_table(rows)
      else
        puts Terminal::Table.new(headings: headings, rows: rows)
      end
    end
    puts 'Only enabled products are shown by default. Use the `--all` option to see all products.' unless options.all or options.csv
  end
  map ls: :list

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
    product_id = Integer(target, 10) rescue nil
    products = []
    if product_id
      product = Product.find(product_id)
      products << product unless product.nil?
    else
      identifier, version, arch = target.split('/')
      conditions = { identifier: identifier, version: version }
      conditions[:arch] = arch if arch
      products = Product.where(conditions).to_a
    end

    if set_enabled
      products.each do |product|
        extensions = Product.recommended_extensions(product.id).to_a
        next if extensions.empty?
        puts "The following required extensions for #{product.product_string} have been enabled: #{extensions.pluck(:name).join(', ')}."
        products.push(*extensions)
      end
    end

    repo_count = repository_service.change_mirroring_by_product!(set_enabled, products.uniq)
    puts "#{repo_count} repo(s) successfully #{set_enabled ? 'enabled' : 'disabled'}."
  rescue ActiveRecord::RecordNotFound
    raise RMT::CLI::Error.new("Product by id \"#{product_id}\" not found.")
  end

  private

  def repository_service
    @repository_service ||= RepositoryService.new
  end

end
