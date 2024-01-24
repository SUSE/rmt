class RepositoryService

  class RepositoryNotFound < RuntimeError
  end

  def create_repository!(product, url, attributes, custom: false)
    repository = if custom
                   Repository.find_or_initialize_by(external_url: url)
                 else
                   # Self Heal and guard against a custom repository with the same URL as the SCC repository
                   # See the migration 20200916104804_make_scc_id_unique.rb for an instance where this is possible
                   Repository.where(external_url: url).where.not(scc_id: attributes[:id]).update(scc_id: nil)
                   Repository.only_custom.where(external_url: url).delete_all

                   Repository.find_or_initialize_by(scc_id: attributes[:id])
                 end

    repository.attributes = attributes.select do |k, _|
      repository.attributes.keys.member?(k.to_s) && k.to_s != 'id'
    end

    if custom
      repository.friendly_id ||= attributes[:id]
    else
      repository.scc_id = attributes[:id]
      repository.friendly_id = attributes[:id]
    end

    repository.external_url = url
    repository.local_path = Repository.make_local_path(url)

    ActiveRecord::Base.transaction do
      repository.save!
      attach_product!(product, repository) unless product.nil?
    end

    repository
  end

  def update_repository!(repo_data)
    uri = URI(repo_data[:url])
    auth_token = uri.query

    Repository.find_by!(scc_id: repo_data[:id]).update!(
      auth_token: auth_token,
      enabled: repo_data[:enabled],
      autorefresh: repo_data[:autorefresh],
      external_url: "#{uri.scheme}://#{uri.host}#{uri.path}",
      local_path: Repository.make_local_path(uri)
    )
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
