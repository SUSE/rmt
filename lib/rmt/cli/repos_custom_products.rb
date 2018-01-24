class RMT::CLI::ReposCustomProducts < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'list ID', 'Shows products attached to a custom repository'
  def list(id)
    repository = find_repository(id)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{id}\"."
      return
    end

    products = repository.products

    if products.empty?
      warn 'No products attached to repository.'
      return
    end
    puts array_to_table(products, {
      id: 'Product ID',
      name: 'Product Name'
    })
  end
  map ls: :list

  desc 'add ID PRODUCT_ID', 'Adds a custom repository to another product'
  def add(id, product_id)
    repository = find_repository(id)
    product = Product.find_by(id: product_id)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{id}\"."
      return
    elsif product.nil?
      warn "Cannot find product by id \"#{product_id}\"."
      return
    end

    repository_service.add_product(product, repository)
    puts 'Added repository to product'
  end

  desc 'remove ID PRODUCT_ID', 'Removes a custom repository from a product'
  def remove(id, product_id)
    repository = find_repository(id)
    product = Product.find_by(id: product_id)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{id}\"."
      return
    elsif product.nil?
      warn "Cannot find product by id \"#{product_id}\"."
      return
    end

    repository_service.remove_product!(product, repository)
    puts 'Removed repository from product'
  end
  map rm: :remove


  private

  def find_repository(id)
    repository = Repository.find_by(id: id)
    return nil if repository && !repository.custom?
    repository
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

end
