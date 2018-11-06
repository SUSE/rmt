require 'rmt/cli/repos'

class RMT::CLI::Products < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  class ProductNotFoundException < StandardError
  end

  desc 'list', 'List products which are marked to be mirrored.'
  option :all, aliases: '-a', type: :boolean, desc: 'List all products, including ones which are not marked to be mirrored'
  option :release_stage, aliases: '-r', type: :string, desc: 'beta, released'
  option :csv, type: :boolean, desc: 'Output data in CSV format'

  def list
    products = (options.all ? Product.all : Product.mirrored).order(:name, :version, :arch)
    products = products.with_release_stage(options[:release_stage])

    if products.empty?
      if options.all
        warn 'Run "rmt-cli sync" to synchronize with your SUSE Customer Center data first.'
      else
        warn 'No matching products found in the database.'
      end
    else
      puts format_array(products, {
        id: 'ID',
        name: 'Name',
        version: 'Version',
        arch: 'Architecture',
        product_string: 'Product string',
        release_stage: 'Release stage',
        'mirror?' => 'Mirror?',
        last_mirrored_at: 'Last mirrored'
      }, options.csv)
    end
    puts 'Only enabled products are shown by default. Use the `--all` option to see all products.' unless options.all || options.csv
  end
  map ls: :list

  desc 'enable TARGETS', 'Enable mirroring of product repositories by a list of product IDs or product strings.'
  option :all_modules, type: :boolean, desc: 'Enables all free modules for a product'
  def enable(*targets)
    change_products(targets, true, options[:all_modules])
  end

  desc 'disable TARGETS', 'Disable mirroring of product repositories by a list of product IDs or product strings.'
  def disable(*targets)
    change_products(targets, false, false)
  end

  protected

  def change_products(targets, set_enabled, all_modules)
    success = true
    targets = clean_target_input(targets)
    raise RMT::CLI::Error.new('No product ids supplied') if targets.empty?

    targets.each do |target|
      change_product(target, set_enabled, all_modules)
    rescue ProductNotFoundException => e
      puts e.message
      success = false
    end

    raise RMT::CLI::Error.new("Not all products were #{set_enabled ? 'enabled' : 'disabled'}.") unless success
  end

  def change_product(target, set_enabled, all_modules)
    products = find_products(target)
    raise ProductNotFoundException.new("Product by target '#{target}' not found.") if products.empty?
    puts "Found product(s) by target #{target}: #{products.map(&:friendly_name).join(', ')}."

    if set_enabled
      products.each do |product|
        extensions = all_modules ? Product.free_and_recommended_modules(product.id).to_a : Product.recommended_extensions(product.id).to_a
        next if extensions.empty?
        puts "  The following required extensions for #{product.product_string} have been enabled: #{extensions.pluck(:name).join(', ')}."
        products.push(*extensions)
      end
    end

    repo_names = repository_service.change_mirroring_by_product!(set_enabled, products.uniq)
    if repo_names.empty?
      puts "  All repositories have already been #{set_enabled ? 'enabled' : 'disabled'}."
    else
      repo_names.each do |repo_name|
        puts "  Repository #{repo_name} has been successfully #{set_enabled ? 'enabled' : 'disabled'}."
      end
    end
  end

  private

  def find_products(target)
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

    products
  rescue ActiveRecord::RecordNotFound
    raise ProductNotFoundException.new("Product by id \"#{product_id}\" not found.")
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

  def clean_target_input(input)
    input.inject([]) { |targets, object| targets + object.split(',') }.reject(&:empty?)
  end

end
