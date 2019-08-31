require 'rmt/cli/repos'

class RMT::CLI::Products < RMT::CLI::Base

  class ProductNotFoundException < StandardError
  end

  desc 'list', _('List products which are marked to be mirrored.')
  option :all, aliases: '-a', type: :boolean, desc: _('List all products, including ones which are not marked to be mirrored')
  option :release_stage, aliases: '-r', type: :string, desc: 'beta, released'
  option :csv, type: :boolean, desc: _('Output data in CSV format')
  def list
    products = (options.all ? Product.all : Product.mirrored).order(:name, :version, :arch)
    products = products.with_release_stage(options[:release_stage])
    decorator = ::RMT::CLI::Decorators::ProductDecorator.new(products)

    if products.empty?
      if options.all
        warn _("Run '%{command}' to synchronize with your SUSE Customer Center data first.") % { command: 'rmt-cli sync' }
      else
        warn _('No matching products found in the database.')
      end
    elsif options.csv
      puts decorator.to_csv
    else
      puts decorator.to_table
    end

    unless options.all || options.csv
      puts _("Only enabled products are shown by default. Use the '%{command}' option to see all products.") % {
        command: '--all'
      }
    end
  end
  map 'ls' => :list

  desc 'enable TARGETS', _('Enable mirroring of product repositories by a list of product IDs or product strings.')
  option :all_modules, type: :boolean, desc: _('Enables all free modules for a product')
  long_desc <<~REPOS
    #{_('Enable mirroring of product repositories by a list of product IDs or product strings.')}

    #{_('Examples')}:

    $ rmt-cli products enable SLES/15

    $ rmt-cli products enable 1575

    $ rmt-cli products enable SLES/15/x86_64 1743

    $ rmt-cli products enable --all-modules SLES/15
  REPOS
  def enable(*targets)
    change_products(targets, true, options[:all_modules])
  end

  desc 'disable TARGETS', _('Disable mirroring of product repositories by a list of product IDs or product strings.')
  long_desc <<~REPOS
    #{_('Disable mirroring of product repositories by a list of product IDs or product strings.')}

    #{_('Examples')}:

    $ rmt-cli products disable SLES/15

    $ rmt-cli products disable 1575

    $ rmt-cli products disable SLES/15/x86_64 1743
  REPOS
  def disable(*targets)
    change_products(targets, false, false)
  end

  desc 'show TARGET', _('Displays product with all its repositories and their attributes.')
  long_desc <<~SHOW
    #{_('Displays product with all its repositories and their attributes.')}

    #{_('Examples')}:

    $ rmt-cli products show SLES/15/x86_64
  SHOW
  def show(target)
    show_product(target)
  end

  protected

  def show_product(target)
    product = find_products(target).first

    raise ProductNotFoundException.new(_('No product found for target %{target}.') % { target: target }) if product.blank?

    puts _('Product: %{name} (id: %{id})') % { name: product.friendly_name, id: product.id }
    puts _('Description: %{description}') % { description: product.description }
    show_product_repos(product)
  rescue ProductNotFoundException => e
    puts e.message
  end

  def show_product_repos(product)
    repos = product.repositories
    puts repos.present? ? _('Repositories:') : _('Repositories are not available for this product.')
    decorator = ::RMT::CLI::Decorators::RepositoryDecorator.new(repos)
    decorator.to_tty
  end

  def change_products(targets, set_enabled, all_modules)
    targets = clean_target_input(targets)
    raise RMT::CLI::Error.new(_('No product IDs supplied')) if targets.empty?

    failed_targets = []
    targets.each do |target|
      change_product(target, set_enabled, all_modules)
    rescue ProductNotFoundException => e
      puts e.message
      failed_targets << target
    end

    unless failed_targets.empty?
      message = if set_enabled
                  n_('Product %{products} could not be found and was not enabled.',
                     'Products %{products} could not be found and were not enabled.',
                     failed_targets.count) % { products: failed_targets.join(', ') }
                else
                  n_('Product %{products} could not be found and was not disabled.',
                     'Products %{products} could not be found and were not disabled.',
                     failed_targets.count) % { products: failed_targets.join(', ') }
                end
      raise RMT::CLI::Error.new(message)
    end
  end

  def change_product(target, set_enabled, all_modules)
    # rubocop:disable Lint/ParenthesesAsGroupedExpression

    # This will return multiple products if 'SLES/15' was used
    base_products = find_products(target)
    raise ProductNotFoundException.new(_('No product found for target %{target}.') % { target: target }) if base_products.empty?
    puts n_('Found product by target %{target}: %{products}.', 'Found products by target %{target}: %{products}.', base_products.count) % {
      products: base_products.map(&:friendly_name).join(', '),
      target: target
    }

    base_products.each do |base_product|
      if set_enabled
        puts _('Enabling %{product}:') % { product: base_product.friendly_name }
      else
        puts _('Disabling %{product}:') % { product: base_product.friendly_name }
      end

      products = [base_product]
      if set_enabled
        extensions = all_modules ? Product.free_and_recommended_modules(base_product.id).to_a : Product.recommended_extensions(base_product.id).to_a
        products.push(*extensions) unless extensions.empty?
      end

      products.each do |product|
        puts "#{product.friendly_name}:".indent(2)
        repo_names = repository_service.change_mirroring_by_product!(set_enabled, product)
        if repo_names.empty?
          puts set_enabled ? _('All repositories have already been enabled.').indent(4) : _('All repositories have already been disabled.').indent(4)
        else
          repo_names.each do |repo_name|
            if set_enabled
              puts (_('Enabled repository %{repository}.') % { repository: repo_name }).indent(4)
            else
              puts (_('Disabled repository %{repository}.') % { repository: repo_name }).indent(4)
            end
          end
        end
      end

      # rubocop:enable Lint/ParenthesesAsGroupedExpression
    end
  end

  private

  def find_products(target)
    Product.get_by_target!(target)
  rescue ActiveRecord::RecordNotFound
    raise ProductNotFoundException.new(_('Product by ID %{id} not found.') % { id: target })
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

  # Allows to have any type of multi input that you want:
  #
  # 1575 (alone)
  # SLES/15/x86_64,1743 (no space but with comma)
  # SLES/15/x86_64, 1743 (space with comma)
  # SLES/15/x86_64 1743 (space but no comma)
  # "SLES/15/x86_64, 1743, SLED/15" (enclosed in spaces)
  def clean_target_input(input)
    input.inject([]) { |targets, object| targets + object.to_s.split(/,|\s/) }.reject(&:empty?)
  end

end
