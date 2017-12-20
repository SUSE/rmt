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
      @logger.debug("Adding product #{item[:identifier]}/#{item[:version]}#{(item[:arch]) ? '/' + item[:arch] : ''}")
      product = create_product(item)
      create_service(item, product)
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
    File.write(File.join(path, 'organizations_products.json'), scc_api_client.list_products.to_json)
    # For SUMA, we also export the unscoped products.
    File.write(File.join(path, 'organizations_products_unscoped.json'), scc_api_client.list_products_unscoped.to_json)

    @logger.info('Exporting repositories')
    File.write(File.join(path, 'organizations_repositories.json'), scc_api_client.list_repositories.to_json)

    @logger.info('Exporting subscriptions')
    File.write(File.join(path, 'organizations_subscriptions.json'), scc_api_client.list_subscriptions.to_json)

    @logger.info('Exporting orders')
    File.write(File.join(path, 'organizations_orders.json'), scc_api_client.list_orders.to_json)
  end

  def import(path)
    missing_files = %w[products repositories subscriptions]
      .map { |data| "organizations_#{data}.json" }
      .reject { |filename| File.exist?(File.join(path, filename)) }
    raise DataFilesError, "Missing data files: #{missing_files.join(', ')}" if missing_files.any?

    @logger.info('Cleaning up the database')
    Subscription.delete_all

    @logger.info("Importing SCC data from #{path}")

    @logger.info('Updating products')
    data = JSON.parse(File.read(File.join(path, 'organizations_products.json')), symbolize_names: true)
    data.each do |item|
      @logger.debug("Adding product #{item[:identifier]}/#{item[:version]}#{(item[:arch]) ? '/' + item[:arch] : ''}")
      product = create_product(item)
      create_service(item, product)
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

  def create_product(item)
    extensions = []

    item[:extensions].each do |ext_item|
      extension = Product.find_or_create_by(id: ext_item[:id])
      extension.attributes = ext_item.select { |k, _| extension.attributes.keys.member?(k.to_s) }
      extension.save!

      create_service(ext_item, extension)
      extensions << extension
    end

    product = Product.find_or_create_by(id: item[:id])
    product.attributes = item.select { |k, _| product.attributes.keys.member?(k.to_s) }
    product.save!

    ProductPredecessorAssociation.where(product_id: product.id).destroy_all
    item[:predecessor_ids].each do |predecessor_id|
      ProductPredecessorAssociation.create(product_id: product.id, predecessor_id: predecessor_id)
    end

    extensions.each do |extension|
      association = ProductsExtensionsAssociation.new
      association.product_id = product.id
      association.extension_id = extension.id
      association.save!
    end

    product
  end

  def create_service(item, product)
    service = Service.find_or_create_by(product_id: product.id)

    item[:repositories].each do |repo_item|
      repository = Repository.find_or_initialize_by(external_url: repo_item[:url])
      repository.attributes = repo_item.select { |k, _| repository.attributes.keys.member?(k.to_s) }
      repository.external_url = repo_item[:url]
      repository.local_path = Repository.make_local_path(repo_item[:url])
      repository.save!

      RepositoriesServicesAssociation.find_or_create_by(
        service_id: service.id,
        repository_id: repository.id
      )
    end
  end

  def update_auth_token(item)
    uri = URI(item[:url])
    auth_token = uri.query

    Repository.find(item[:id]).update! auth_token: auth_token
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

end
