class CreateRepositoryService

  class InvalidExternalUrl < RuntimeError
  end

  def call(product_service, url, attributes, custom: false)
    repository = Repository.find_or_initialize_by(external_url: url)

    # TODO: See if we can clean this up
    repository.attributes = attributes.select do |k, _|
      repository.attributes.keys.member?(k.to_s) && k.to_s != 'id'
    end
    repository.scc_id = attributes[:id] unless custom

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

end
