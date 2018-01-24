class RMT::CLI::ReposCustom < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'add URL NAME PRODUCT_ID', 'Add a custom repository to a product'
  def add(url, name, product_id)
    product = Product.find_by(id: product_id)
    previous_repository = Repository.find_by(external_url: url)

    if product.nil?
      warn "Cannot find product by id #{product_id}."
      return
    elsif previous_repository
      warn 'A repository by this URL already exists.'
      return
    end

    begin
      repository_service.create_repository(product, url, {
        name: name,
        mirroring_enabled: true,
        autorefresh: 1,
        enabled: 0
      }, custom: true)

      puts 'Successfully added custom repository.'
    rescue RepositoryService::InvalidExternalUrl => e
      warn "Invalid URL \"#{e.message}\" provided."
    end
  end

  desc 'list', 'List all custom repositories'
  def list
    repositories = Repository.only_custom

    if repositories.empty?
      warn 'No custom repositories found.'
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

  desc 'remove ID', 'Remove a custom repository'
  def remove(id)
    repository = find_repository(id)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{id}\"."
      return
    end

    repository.destroy!
    puts "Removed custom repository by id \"#{repository.id}\"."
  end
  map rm: :remove

  desc 'products', 'List and modify custom repository products'
  subcommand 'products', RMT::CLI::ReposCustomProducts

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
