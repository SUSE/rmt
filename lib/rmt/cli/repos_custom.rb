class RMT::CLI::ReposCustom < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'add URL NAME', 'Creates a custom repository.'
  def add(url, name)
    url += '/' unless url.end_with?('/')

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

    raise RMT::CLI::Error.new('No custom repositories found.') if repositories.empty?

    puts array_to_table(repositories, {
      id: 'ID',
      name: 'Name',
      external_url: 'URL',
      enabled: 'Mandatory?',
      mirroring_enabled: 'Mirror?',
      last_mirrored_at: 'Last Mirrored'
    })
  end
  map ls: :list

  desc 'enable ID', 'Enable mirroring of custom repository by ID'
  def enable(id)
    change_mirroring(id, true)
  end

  desc 'disable ID', 'Disable mirroring of custom repository by ID'
  def disable(id)
    change_mirroring(id, false)
  end

  desc 'remove ID', 'Remove a custom repository'
  def remove(id)
    repository = find_repository!(id)
    repository.destroy!

    puts "Removed custom repository by id \"#{id}\"."
  end
  map rm: :remove

  desc 'products ID', 'Shows products attached to a custom repository'
  def products(id)
    repository = find_repository!(id)
    products = repository.products

    raise RMT::CLI::Error.new('No products attached to repository.') if products.empty?

    puts array_to_table(products, {
      id: 'Product ID',
      name: 'Product Name'
    })
  end

  desc 'attach ID PRODUCT_ID', 'Attach an existing custom repository to a product'
  def attach(id, product_id)
    product, repository = attach_or_detach(id, product_id)
    repository_service.attach_product!(product, repository)

    puts "Attached repository to product \"#{product.name}\"."
  end

  desc 'detach ID PRODUCT_ID', 'Detach an existing custom repository from a product'
  def detach(id, product_id)
    product, repository = attach_or_detach(id, product_id)
    repository_service.detach_product!(product, repository)

    puts "Detached repository from product \"#{product.name}\"."
  end

  private

  def change_mirroring(id, set_enabled)
    repository = find_repository!(id)
    repository.change_mirroring!(set_enabled)

    puts "Repository successfully #{set_enabled ? 'enabled' : 'disabled'}."
  end

  def find_repository!(id)
    repository = Repository.find_by!(id: id)
    raise StandardError unless repository.custom?
    repository
  rescue
    raise RMT::CLI::Error.new("Cannot find custom repository by id \"#{id}\".")
  end

  def find_product!(id)
    Product.find_by!(id: id)
  rescue ActiveRecord::RecordNotFound
    raise RMT::CLI::Error.new("Cannot find product by id \"#{id}\".")
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

  def attach_or_detach(id, product_id)
    repository = find_repository!(id)
    product = find_product!(product_id)

    [product, repository]
  end

end
