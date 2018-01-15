class RepositoryService

  class InvalidExternalUrl < RuntimeError
  end

  def repository_by_id(repository_id)
    Repository.find_by(id: repository_id)
  end

  def repository_by_url(url)
    Repository.find_by(external_url: url)
  end

  def create_repository(product_service, url, attributes, is_custom_repository = false)
    repository = Repository.find_or_initialize_by(external_url: url)

    # TODO: See if we can clean this up
    repository.attributes = attributes.select do |k, _|
      repository.attributes.keys.member?(k.to_s) && k.to_s != 'id'
    end
    repository.scc_id = attributes[:id] unless is_custom_repository

    repository.external_url = url
    repository.local_path = Repository.make_local_path(url)

    raise InvalidExternalUrl.new(url) if repository.local_path.to_s == ''

    ActiveRecord::Base.transaction do
      repository.save!

      RepositoriesServicesAssociation.find_or_create_by(
        service_id: product_service.id,
        repository_id: repository.id
      )
    end

    repository
  end

  def remove_repository(repository)
    return unless repository.custom?
    repository.destroy!
  end

end
