class RMT::CLI::ReposCustom < RMT::CLI::ReposBase

  desc 'add URL NAME', _('Creates a custom repository.')
  option :id, type: :string, desc: _('Provide a custom ID instead of allowing RMT to generate one.')
  long_desc <<-REPOS
#{_('Creates a custom repository.')}

#{_('Examples:')}

$ rmt-cli repos custom add https://download.opensuse.org/repositories/Virtualization:/containers/SLE_12_SP3/ Virtualization:Containers

$ rmt-cli repos custom add https://download.opensuse.org/repositories/Virtualization:/containers/SLE_12_SP3/ Virtualization:Containers --id containers_sle_12_sp3`
  REPOS
  def add(url, name)
    url += '/' unless url.end_with?('/')
    friendly_id = options.id.to_s

    if Repository.find_by(external_url: url)
      raise RMT::CLI::Error.new(_('A repository by the URL %{url} already exists.') % { url: url })
    end

    if /^[0-9]+$/.match?(friendly_id) # numeric IDs are reserved for SCC repositories
      raise RMT::CLI::Error.new(_('Please provide a non-numeric ID for your custom repository.'))
    elsif Repository.find_by(friendly_id: friendly_id)
      raise RMT::CLI::Error.new(_('A repository by the ID %{id} already exists.') % { id: friendly_id })
    end

    repository_service.create_repository!(nil, url, {
      name: name,
      mirroring_enabled: true,
      autorefresh: true,
      enabled: 0,
      id: friendly_id
    }, custom: true)

    puts _('Successfully added custom repository.')
  end

  desc 'list', _('List all custom repositories')
  option :csv, type: :boolean, desc: _('Output data in CSV format')
  def list
    repositories = Repository.only_custom.order(:name)
    decorator = ::RMT::CLI::Decorators::CustomRepositoryDecorator.new(repositories)

    raise RMT::CLI::Error.new(_('No custom repositories found.')) if repositories.empty?

    if options.csv
      puts decorator.to_csv
    else
      puts decorator.to_table
    end
  end
  map 'ls' => :list

  desc 'enable ID', _('Enable mirroring of custom repositories by a list of IDs')
  long_desc <<-REPOS
#{_('Enable mirroring of custom repositories by a list of IDs')}

#{_('Examples:')}

$ rmt-cli repos custom enable e133a7b26a7701b1d65a61683e50512b

$ rmt-cli repos custom enable e133a7b26a7701b1d65a61683e50512b 7726fb7f1954d786860426b47748856c
  REPOS
  def enable(*ids)
    change_repos(ids, true, custom: true)
  end

  desc 'disable ID', _('Disable mirroring of custom repository by a list of IDs')
  long_desc <<-REPOS
#{_('Disable mirroring of custom repositories by a list of IDs')}

#{_('Examples:')}

$ rmt-cli repos custom disable e133a7b26a7701b1d65a61683e50512b

$ rmt-cli repos custom disable e133a7b26a7701b1d65a61683e50512b 7726fb7f1954d786860426b47748856c
  REPOS
  def disable(*ids)
    change_repos(ids, false, custom: true)

    puts "\n\e[1m" + _("To clean up downloaded files, please run '%{command}'") % { command: 'rmt-cli repos clean' } + "\e[22m"
  end

  desc 'remove ID', _('Remove a custom repository')
  def remove(id)
    repository = find_repository!(id, custom: true)
    repository.destroy!

    puts _('Removed custom repository by ID %{id}.') % { id: id }
  rescue RepoNotFoundException => e
    raise RMT::CLI::Error.new(e.message)
  end
  map 'rm' => :remove

  desc 'products ID', _('Shows products attached to a custom repository')
  option :csv, type: :boolean, desc: _('Output data in CSV format')

  def products(id)
    repository = find_repository!(id, custom: true)
    products = repository.products
    decorator = ::RMT::CLI::Decorators::CustomRepositoryProductsDecorator.new(products)

    raise RMT::CLI::Error.new(_('No products attached to repository.')) if products.empty?
    if options.csv
      puts decorator.to_csv
    else
      puts decorator.to_table
    end
  rescue RepoNotFoundException => e
    raise RMT::CLI::Error.new(e.message)
  end

  desc 'attach ID PRODUCT_ID', _('Attach an existing custom repository to a product')
  def attach(id, product_id)
    repository = find_repository!(id, custom: true)
    product = find_product!(product_id)
    repository_service.attach_product!(product, repository)

    puts _("Attached repository to product '%{product_name}'.") % { product_name: product.name }
  rescue RepoNotFoundException => e
    raise RMT::CLI::Error.new(e.message)
  end

  desc 'detach ID PRODUCT_ID', _('Detach an existing custom repository from a product')
  def detach(id, product_id)
    repository = find_repository!(id, custom: true)
    product = find_product!(product_id)
    repository_service.detach_product!(product, repository)

    puts _("Detached repository from product '%{product_name}'.") % { product_name: product.name }
  rescue RepoNotFoundException => e
    raise RMT::CLI::Error.new(e.message)
  end

  private

  def find_product!(id)
    Product.find_by!(id: id)
  rescue ActiveRecord::RecordNotFound
    raise RMT::CLI::Error.new(_('Cannot find product by ID %{id}.') % { id: id })
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

end
