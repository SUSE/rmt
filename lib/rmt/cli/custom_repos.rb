class RMT::CLI::CustomRepos < RMT::CLI::Base

  include ::RMT::CLI::RepoPrintable

  desc 'add', 'Adds a custom repository to a product'
  option :name, aliases: '-n', type: :string, desc: 'The name of the custom repository', required: true
  option :url, aliases: '-u', type: :string, desc: 'Absolute external URL to this repository', required: true
  option :update, type: :boolean, desc: 'Update repository instead of ignore when it already exists', default: false
  option :product_id, aliases: '-p', type: :string, required: true,
         desc: 'The id of the product where the repository should be added. Use `rmt-cli products list` to see products'
  def add
    product = Product.find_by(id: options[:product_id])

    if product.nil?
      warn "Cannot find product by id #{options[:product_id]}."
      return
    end

    service = product_service.get_service(product)
    previous_repository = repository_service.repository_by_url(options[:url])

    if previous_repository && !options[:update]
      warn "A repository by url \"#{options[:url]}\" already exists."
      return
    elsif previous_repository && !previous_repository.custom?
      warn "A non-custom repository by url \"#{options[:url]}\" already exists."
      return
    end

    begin
      repository_service.create_repository(service, options[:url], {
        name: options[:name],
        mirroring_enabled: true,
        description: options[:name],
        autorefresh: 1,
        enabled: 0
      }, true)

      if previous_repository
        puts 'Successfully updated custom repository.'
      else
        puts 'Successfully added custom repository.'
      end
    rescue RepositoryService::InvalidExternalUrl => e
      warn "Invalid url \"#{e.message}\" provided."
    end
  end

  desc 'ls', 'Lists the custom repositories used in RMT'
  def list
    repositories = Repository.only_custom

    if repositories.empty?
      warn 'No custom repositories found.'
    else
      puts repositories_to_table(repositories)
    end
  end
  map ls: :list

  desc 'rm REPOSITORY_ID', 'Removes a custom repository from RMT'
  def remove(repository_id)
    repository = repository_service.repository_by_id(repository_id)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{repository_id}\"."
      return
    end

    unless repository.custom?
      warn 'Cannot remove non-custom repositories.'
      return
    end

    repository_service.remove_repository(repository)
    puts "Removed custom repository by id \"#{repository.id}\"."
  end
  map rm: :remove

  private

  def repository_service
    @repository_service ||= ::RepositoryService.new
  end

  def product_service
    @product_service ||= ::ProductService.new
  end

end
