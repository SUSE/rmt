require 'suse/connect/api'
require 'rmt/config'

class RMT::SCCSync

  def initialize(logger = nil)
    @logger = logger || Logger.new(nil)
  end

  def sync
    @logger.info('Cleaning up the database')
    clean_up

    @logger.info('Downloading data from SCC')
    scc_api_client = SUSE::Connect::Api.new(Settings.scc.username, Settings.scc.password)
    data = scc_api_client.list_products

    @logger.info('Updating the database')
    data.each do |item|
      @logger.debug("Adding product #{item[:name]}")
      product = create_product(item)
      create_service(item, product)
    end

    @logger.info('Done!')
  end

  protected

  def clean_up
    Product.delete_all
    Repository.delete_all
  end

  def create_product(item)
    extensions = []

    item[:extensions].each do |ext_item|
      begin
        extension = Product.find(ext_item[:id])
      rescue
        extension = Product.new
        extension.attributes = ext_item.select { |k, _| extension.attributes.keys.member?(k.to_s) }
        extension.save!
      end

      create_service(ext_item, extension)
      extensions << extension
    end

    begin
      product = Product.new
      product.attributes = item.select { |k, _| product.attributes.keys.member?(k.to_s) }
      product.save!
    rescue ActiveRecord::RecordNotUnique # rubocop:disable Lint/HandleExceptions
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
    repositories = []

    item[:repositories].each do |repo_item|
      begin
        repository = Repository.new
        repository.attributes = repo_item.select { |k, _| repository.attributes.keys.member?(k.to_s) }
        repository.external_url = repo_item[:url]
        repository.save!
      rescue ActiveRecord::RecordNotUnique
        repository = Repository.where(name: repo_item[:name], distro_target: repo_item[:distro_target]).first
      end

      repositories << repository
    end

    service = Service.find_or_create_by(product_id: product.id)
    service.repositories = repositories
    service.save!
  end

end
