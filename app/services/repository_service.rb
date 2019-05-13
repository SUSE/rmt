class RepositoryService

  class RepositoryNotFound < RuntimeError
  end

  def create_repository!(product, url, attributes, custom: false)
    repository = Repository.find_or_initialize_by(external_url: url)

    repository.attributes = attributes.select do |k, _|
      repository.attributes.keys.member?(k.to_s) && k.to_s != 'id'
    end
    repository.scc_id = attributes[:id] unless custom

    repository.external_url = url
    repository.local_path = Repository.make_local_path(url)

    ActiveRecord::Base.transaction do
      repository.save!
      attach_product!(product, repository) unless product.nil?
    end

    repository
  end

  def attach_product!(product, repository)
    RepositoriesServicesAssociation.find_or_create_by!(
      service_id: product.service.id,
      repository_id: repository.id
    )
  end

  def detach_product!(product, repository)
    association = RepositoriesServicesAssociation.find_by(
      service_id: product.service.id,
      repository_id: repository.id
    )
    association.destroy!
  end

  def change_mirroring_by_product!(mirroring_enabled, product)
    conditions = { mirroring_enabled: !mirroring_enabled } # to only update the repos which need change
    conditions[:enabled] = true if mirroring_enabled
    product.change_repositories_mirroring!(conditions, mirroring_enabled)
  end
end
