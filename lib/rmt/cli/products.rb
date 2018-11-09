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
  long_desc <<-REPOS

Examples:

`rmt-cli products enable SLES/15`

`rmt-cli products enable 1575`

`rmt-cli products enable SLES/15/x86_64,1743`

`rmt-cli products enable --all-modules SLES/15`
REPOS
  def enable(*targets)
    change_products(targets, true, options[:all_modules])
  end

  desc 'disable TARGETS', 'Disable mirroring of product repositories by a list of product IDs or product strings.'
  def disable(*targets)
    change_products(targets, false, false)
  end

  protected

  def change_products(targets, set_enabled, all_modules)
    targets = clean_target_input(targets)
    raise RMT::CLI::Error.new('No product ids supplied') if targets.empty?

    failed_targets = []
    targets.each do |target|
      change_product(target, set_enabled, all_modules)
    rescue ProductNotFoundException => e
      puts e.message
      failed_targets << target
    end

    unless failed_targets.empty?
      message = if set_enabled
                  "Product(s) #{failed_targets.join(',')} could not be found and were not enabled."
                else
                  "Product(s) #{failed_targets.join(',')} could not be found and were not disabled."
                end
      raise RMT::CLI::Error.new(message)
    end
  end

  def change_product(target, set_enabled, all_modules)
    # This will return multiple products if 'SLES/15' was used
    base_products = find_products(target)
    raise ProductNotFoundException.new("No product found for target '#{target}'.") if base_products.empty?
    puts "Found product(s) by target #{target}: #{base_products.map(&:friendly_name).join(', ')}."

    base_products.each do |base_product|
      puts "#{set_enabled ? 'Enabling' : 'Disabling'} #{base_product.friendly_name}:"

      products = [base_product]
      if set_enabled
        extensions = all_modules ? Product.free_and_recommended_modules(base_product.id).to_a : Product.recommended_extensions(base_product.id).to_a
        products.push(*extensions) unless extensions.empty?
      end

      products.each do |product|
        puts "#{product.friendly_name}:".indent(2)
        repo_names = repository_service.change_mirroring_by_product!(set_enabled, product)
        if repo_names.empty?
          puts "All repositories have already been #{set_enabled ? 'enabled' : 'disabled'}.".indent(4)
        else
          repo_names.each do |repo_name|
            puts "#{set_enabled ? 'Enabled' : 'Disabled'} repository #{repo_name}.".indent(4)
          end
        end
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
