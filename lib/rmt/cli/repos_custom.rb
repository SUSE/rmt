class RMT::CLI::ReposCustom < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'add URL NAME', 'Creates a custom repository.'
  def add(url, name)
    url << '/' unless url.end_with?('/')

    previous_repository = Repository.find_by(external_url: url)

    if previous_repository
      raise RMT::CLI::Error.new('A repository by this URL already exists.')
    end

    repository_service.create_repository!(nil, url, {
      name: name,
      mirroring_enabled: 1,
      autorefresh: 1,
      enabled: 0
    }, custom: true)

    puts 'Successfully added custom repository.'
  end

  desc 'list', 'List all custom repositories'
  def list
    repositories = Repository.only_custom

    if repositories.empty?
      raise RMT::CLI::Error.new('No custom repositories found.')
    else
      puts array_to_table(repositories, {
        id: 'ID',
        name: 'Name',
        external_url: 'URL',
        enabled: 'Mandatory?',
        mirroring_enabled: 'Mirror?',
        last_mirrored_at: 'Last Mirrored'
      })
    end
  end
  map ls: :list

  desc 'enable TARGET', 'Enable mirroring of custom repository by ID'
  def enable(target)
    change_mirroring(target, true)
  end

  desc 'disable TARGET', 'Disable mirroring of custom repository by ID'
  def disable(target)
    change_mirroring(target, false)
  end

  desc 'remove ID', 'Remove a custom repository'
  def remove(id)
    repository = find_repository(id)

    if repository.nil?
      raise RMT::CLI::Error.new("Cannot find custom repository by id \"#{id}\".")
    end

    repository.destroy!
    puts "Removed custom repository by id \"#{repository.id}\"."
  end
  map rm: :remove

  desc 'products ID', 'Shows products attached to a custom repository'
  def products(id)
    repository = find_repository(id)

    if repository.nil?
      raise RMT::CLI::Error.new("Cannot find custom repository by id \"#{id}\".")
    end

    products = repository.products

    if products.empty?
      raise RMT::CLI::Error.new('No products attached to repository.')
    end
    puts array_to_table(products, {
      id: 'Product ID',
      name: 'Product Name'
    })
  end

  desc 'attach ID PRODUCT_ID', 'Attach an existing custom repository to a product'
  def attach(id, product_id)
    product, repository = attach_or_detach(id, product_id)
    repository_service.attach_product!(product, repository)
    puts 'Attached repository to product'
  end

  desc 'detach ID PRODUCT_ID', 'Detach an existing custom repository from a product'
  def detach(id, product_id)
    product, repository = attach_or_detach(id, product_id)
    repository_service.detach_product!(product, repository)
    puts 'Detached repository from product'
  end

  private

  def change_mirroring(target, set_enabled)
    repository_service.change_repository_mirroring!(target, set_enabled, scc_repository: false)
    puts "Repository successfully #{set_enabled ? 'enabled' : 'disabled'}."
  rescue RepositoryService::RepositoryNotFound => e
    raise RMT::CLI::Error.new(e.message)
  end

  def find_repository(id)
    repository = Repository.find_by(id: id)
    return nil if repository && !repository.custom?
    repository
  end

  def find_product(id)
    Product.find_by(id: id)
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

  def attach_or_detach(id, product_id)
    repository = find_repository(id)
    product = find_product(product_id)

    if repository.nil?
      raise RMT::CLI::Error.new("Cannot find custom repository by id \"#{id}\".")
    elsif product.nil?
      raise RMT::CLI::Error.new("Cannot find product by id \"#{product_id}\".")
    end

    [product, repository]
  end

end
