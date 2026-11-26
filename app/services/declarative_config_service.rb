class DeclarativeConfigService
  def self.enforce!
    configured_products = Settings.try(:products)
    if configured_products.present?
      Rails.logger.info('Applying products configuration')
      enforce_products!(configured_products)
    end

    configured_custom_repositories = Settings.try(:custom_repositories)
    if configured_custom_repositories.present?
      Rails.logger.info('Applying custom repositories configuration')
      enforce_custom_repositories!(configured_custom_repositories)
    end
  end

  def self.enforce_products!(configured_products)
    configured_products.each do |target|
      products = Product.get_by_target!(target)

      products.each do |product|
        RepositoryService.new.change_mirroring_by_product!(true, product)
      end
    end

    Product.all.each do |product|
      unless configured_products.include?(product.product_string)
        RepositoryService.new.change_mirroring_by_product!(false, product)
      end
    end
  end

  def self.enforce_custom_repositories!(configured_repositories)
    configured_names = configured_repositories.keys.map(&:to_s)

    repository_service = RepositoryService.new

    configured_repositories.each do |name, url|
      name_str = name.to_s
      url_str = url.to_s

      # update_or_create_repository will only match based on url,
      # hence we first check if the url for an existing entry matched by name changed
      existing_repo = Repository.only_custom.find_by(friendly_id: name_str)
      if existing_repo && existing_repo.external_url != url_str
        existing_repo.update!(
          external_url: url_str,
          local_path: Repository.make_local_path(url_str)
        )
      end

      repository_service.update_or_create_repository!(
        nil,
        url_str,
        { name: name_str, id: name_str, enabled: true, mirroring_enabled: true },
        custom: true
      )
    end

    Repository.only_custom.each do |repository|
      unless configured_names.include?(repository.friendly_id)
        repository.destroy!
      end
    end
  end
end
