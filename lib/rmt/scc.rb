require 'rmt/config'
require 'suse/connect/api'

class RMT::SCC

  class CredentialsError < RuntimeError; end
  class DataFilesError < RuntimeError; end

  def initialize(options = {})
    @logger = Logger.new(STDOUT)
    @logger.level = (options[:debug]) ? Logger::DEBUG : Logger::INFO
  end

  def sync
    raise CredentialsError, 'SCC credentials not set.' unless (Settings.scc.username && Settings.scc.password)

    @logger.info('Cleaning up the database')
    Subscription.delete_all

    @logger.info('Downloading data from SCC')
    scc_api_client = SUSE::Connect::Api.new(Settings.scc.username, Settings.scc.password)

    @logger.info('Updating products')
    data = scc_api_client.list_products
    data.each do |item|
      create_product(item) if (item[:product_type] == 'base')
    end
    # with this loop, we create the migration paths after creating all products from sync, thus avoiding fk_constraint errors
    data.each do |item|
      migration_paths(item) if (item[:product_type] == 'base')
    end

    @logger.info('Updating repositories')
    data = scc_api_client.list_repositories
    data.each do |item|
      update_auth_token(item)
    end

    Repository.remove_suse_repos_without_tokens!

    @logger.info('Updating subscriptions')
    data = scc_api_client.list_subscriptions
    data.each do |item|
      create_subscription(item)
    end
  end

  def export(path)
    raise CredentialsError, 'SCC credentials not set.' unless (Settings.scc.username && Settings.scc.password)

    @logger.info("Exporting data from SCC to #{path}")

    scc_api_client = SUSE::Connect::Api.new(Settings.scc.username, Settings.scc.password)

    @logger.info('Exporting products')
    File.write(File.join(path, 'organizations_products_scoped.json'), scc_api_client.list_products.to_json)
    # For SUMA, we also export the unscoped products with the filename it expects.
    File.write(File.join(path, 'organizations_products.json'), scc_api_client.list_products_unscoped.to_json)

    @logger.info('Exporting repositories')
    File.write(File.join(path, 'organizations_repositories.json'), scc_api_client.list_repositories.to_json)

    @logger.info('Exporting subscriptions')
    File.write(File.join(path, 'organizations_subscriptions.json'), scc_api_client.list_subscriptions.to_json)

    @logger.info('Exporting orders')
    File.write(File.join(path, 'organizations_orders.json'), scc_api_client.list_orders.to_json)
  end

  def import(path)
    missing_files = %w[products_scoped repositories subscriptions]
      .map { |data| "organizations_#{data}.json" }
      .reject { |filename| File.exist?(File.join(path, filename)) }
    raise DataFilesError, "Missing data files: #{missing_files.join(', ')}" if missing_files.any?

    @logger.info('Cleaning up the database')
    Subscription.delete_all

    @logger.info("Importing SCC data from #{path}")

    @logger.info('Updating products')
    data = JSON.parse(File.read(File.join(path, 'organizations_products_scoped.json')), symbolize_names: true)
    data.each do |item|
      @logger.debug("Adding product #{item[:identifier]}/#{item[:version]}#{(item[:arch]) ? '/' + item[:arch] : ''}")
      create_product(item)
    end
    data.each do |item|
      migration_paths(item)
    end

    @logger.info('Updating repositories')
    data = JSON.parse(File.read(File.join(path, 'organizations_repositories.json')), symbolize_names: true)
    data.each do |item|
      update_auth_token(item)
    end

    Repository.remove_suse_repos_without_tokens!

    @logger.info('Updating subscriptions')
    data = JSON.parse(File.read(File.join(path, 'organizations_subscriptions.json')), symbolize_names: true)
    data.each do |item|
      create_subscription(item)
    end
  end

  protected

  def get_product(id)
    Product.find_or_create_by(id: id)
  end

  def create_product(item, root_product_id = nil, base_product = nil, recommended = false)
    @logger.debug("Adding product #{item[:identifier]}/#{item[:version]}#{(item[:arch]) ? '/' + item[:arch] : ''}")

    product = get_product(item[:id])
    product.attributes = item.select { |k, _| product.attributes.keys.member?(k.to_s) }
    product.save!

    create_service(item, product)

    if root_product_id
      ProductsExtensionsAssociation.create(
        product_id: base_product,
        extension_id: product.id,
        root_product_id: root_product_id,
        recommended: recommended
      )
    else
      root_product_id = product.id
      ProductsExtensionsAssociation.where(root_product_id: root_product_id).destroy_all
    end

    item[:extensions].each do |ext_item|
      create_product(ext_item, root_product_id, product.id, ext_item[:recommended])
    end
  end

  def create_service(item, product)
    item[:repositories].each do |repo_item|
      repository_service.create_repository!(product, repo_item[:url], repo_item)
    end
  end

  def update_auth_token(item)
    uri = URI(item[:url])
    auth_token = uri.query

    # Sometimes the extension is available, but a base product is not, e.g.:
    # sle-hae/11.3/s390x available without base product for s390x
    # In this case no repository data was added in create_product -- can't update those repos.
    begin
      Repository.find_by!(scc_id: item[:id]).update! auth_token: auth_token
    rescue ActiveRecord::RecordNotFound
      @logger.debug("Repository #{item[:id]} is not available")
    end
  end

  def create_subscription(item)
    subscription = Subscription.new
    subscription.attributes = item.select { |k, _| subscription.attributes.keys.member?(k.to_s) }
    subscription.kind = item[:type]
    subscription.save!

    item[:product_classes].each do |item_class|
      subscription_product_class = SubscriptionProductClass.new
      subscription_product_class.subscription_id = subscription.id
      subscription_product_class.product_class = item_class
      subscription_product_class.save!
    end
  end

  def migration_paths(item)
    product = get_product(item[:id])
    ProductPredecessorAssociation.where(product_id: product.id).destroy_all
    create_migration_path(product, item[:online_predecessor_ids], :online)
    create_migration_path(product, item[:offline_predecessor_ids], :offline)
    item[:extensions].each do |ext_item|
      migration_paths(ext_item)
    end
  end

  def create_migration_path(product, predecessors, kind)
    predecessors.each do |predecessor_id|
      ProductPredecessorAssociation.create(product_id: product.id, predecessor_id: predecessor_id, kind: kind) unless Product.find_by(id: predecessor_id).nil?
    end
  end

  private

  def repository_service
    @repository_service ||= RepositoryService.new
  end

end
