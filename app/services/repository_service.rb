class RepositoryService

  class InvalidExternalUrl < RuntimeError
  end

  def create_repository!(product, url, attributes, custom: false)
    repository = Repository.find_or_initialize_by(external_url: url)

    # TODO: See if we can clean this up
    repository.attributes = attributes.select do |k, _|
      repository.attributes.keys.member?(k.to_s) && k.to_s != 'id'
    end
    repository.scc_id = attributes[:id] unless custom

    repository.external_url = url
    repository.local_path = Repository.make_local_path(url)

    raise InvalidExternalUrl.new(url) if repository.local_path.to_s == '' || repository.local_path.to_s == '/'

    ActiveRecord::Base.transaction do
      repository.save!
      attach_product!(product, repository)
    end

    repository
  end

  def attach_product!(product, repository)
    product_service = find_product_service(product)
    RepositoriesServicesAssociation.find_or_create_by!(
      service_id: product_service.id,
      repository_id: repository.id
    )
  end

  def detach_product!(product, repository)
    product_service = find_product_service(product)
    association = RepositoriesServicesAssociation.find_by(
      service_id: product_service.id,
      repository_id: repository.id
    )
    association.destroy!
  end

  private

  def find_product_service(product)
    Service.find_or_create_by(product_id: product.id)
  end

end
