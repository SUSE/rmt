class RMT::CLI::CustomRepos < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'add URL NAME PRODUCT_ID', 'Add a custom repository to a product'
  def add(url, name, product_id)
    product = Product.find_by(id: product_id)

    if product.nil?
      warn "Cannot find product by id #{product_id}."
      return
    end

    service = product.service
    previous_repository = Repository.by_url(url)

    if previous_repository && !previous_repository.custom?
      warn "A non-custom repository by URL \"#{url}\" already exists."
      return
    end

    begin
      create_repository_service.call(service, url, {
        name: name,
        mirroring_enabled: true,
        autorefresh: 1,
        enabled: 0
      }, custom: true)

      puts 'Successfully added custom repository.'
    rescue CreateRepositoryService::InvalidExternalUrl => e
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
        enabled: 'Mandatory?',
        mirroring_enabled: 'Mirror?',
        last_mirrored_at: 'Last Mirrored'
      })
    end
  end
  map ls: :list

  desc 'remove ID', 'Remove a custom repository'
  def remove(repository_id)
    repository = Repository.by_id(repository_id, custom: true)

    if repository.nil?
      warn "Cannot find custom repository by id \"#{repository_id}\"."
      return
    end

    unless repository.destroy
      warn 'Cannot remove non-custom repositories.'
      return
    end

    puts "Removed custom repository by id \"#{repository.id}\"."
  end
  map rm: :remove

  private

  def create_repository_service
    @create_repository_service ||= CreateRepositoryService.new
  end

end
