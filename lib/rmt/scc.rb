require 'rmt/config'
require 'rmt/logger'
require 'suse/connect/api'

class RMT::SCC
  class CredentialsError < RuntimeError; end
  class DataFilesError < RuntimeError; end

  def initialize(options = {})
    @logger = RMT::Logger.new(STDOUT)
    debug = options[:debug] || Settings&.log_level&.cli == 'debug'
    @logger.level = debug ? Logger::DEBUG : Logger::INFO
  end

  def sync
    credentials_set? || (raise CredentialsError, _('SCC credentials not set.'))

    @logger.info(_('Downloading data from SCC'))
    scc_api_client = SUSE::Connect::Api.new(Settings.scc.username, Settings.scc.password)

    data = scc_api_client.list_products
    @logger.info(_('Updating products'))
    data.each { |item| create_product(item) }
    data.each { |item| migration_paths(item) }

    # Update repositories with details (eg. access token) from API
    repositories_data = scc_api_client.list_repositories
    update_repositories(repositories_data)

    Repository.remove_suse_repos_without_tokens!
    remove_obsolete_repositories(repositories_data)

    update_subscriptions(scc_api_client.list_subscriptions)
  end

  def remove_obsolete_repositories(repos_data)
    @logger.info _('Removing obsolete repositories')
    return if repos_data.empty?

    scc_repo_ids = repos_data.pluck(:id)


    # Find repositories in RMT that no longer exist in SCC
    # Only consider repositories that have a non-null scc_id
    repos_to_remove = Repository.only_scc.where.not(scc_id: scc_repo_ids)
    if repos_to_remove.any?
      repos_to_remove.destroy_all
      @logger.debug("Successfully removed #{repos_to_remove.count} obsolete repositories")
    end
  end

  def export(path)
    credentials_set? || (raise CredentialsError, 'SCC credentials not set.')

    @logger.info _('Exporting data from SCC to %{path}') % { path: path }

    scc_api_client = SUSE::Connect::Api.new(Settings.scc.username, Settings.scc.password)

    @logger.info(_('Exporting products'))
    File.write(File.join(path, 'organizations_products.json'), scc_api_client.list_products.to_json)
    # For SUMA, we also export the unscoped products with the filename it expects.
    File.write(File.join(path, 'organizations_products_unscoped.json'), scc_api_client.list_products_unscoped.to_json)

    @logger.info(_('Exporting repositories'))
    File.write(File.join(path, 'organizations_repositories.json'), scc_api_client.list_repositories.to_json)

    @logger.info(_('Exporting subscriptions'))
    File.write(File.join(path, 'organizations_subscriptions.json'), scc_api_client.list_subscriptions.to_json)

    @logger.info(_('Exporting orders'))
    File.write(File.join(path, 'organizations_orders.json'), scc_api_client.list_orders.to_json)
  end

  def import(path)
    missing_files = %w[products repositories subscriptions]
      .map { |data| "organizations_#{data}.json" }
      .reject { |filename| File.exist?(File.join(path, filename)) }
    raise DataFilesError, _('Missing data files: %{files}') % { files: missing_files.join(', ') } if missing_files.any?

    @logger.info _('Importing SCC data from %{path}') % { path: path }

    @logger.info _('Updating products')
    data = JSON.parse(File.read(File.join(path, 'organizations_products.json')), symbolize_names: true)
    data.each do |item|
      create_product(item)
    end
    data.each { |item| migration_paths(item) }

    update_repositories(JSON.parse(File.read(File.join(path, 'organizations_repositories.json')), symbolize_names: true))

    Repository.remove_suse_repos_without_tokens!

    update_subscriptions(JSON.parse(File.read(File.join(path, 'organizations_subscriptions.json')), symbolize_names: true))
  end

  def sync_systems
    if Settings.scc.sync_systems == false
      @logger.warn _('Syncing systems to SCC is disabled by the configuration file, exiting.')
      return
    end

    credentials_set? || (raise CredentialsError, _('SCC credentials not set.'))
    scc_api_client = SUSE::Connect::Api.new(Settings.scc.username, Settings.scc.password)

    # do not sync BYOS proxy systems to SCC
    systems = System.where('scc_registered_at IS NULL OR last_seen_at > scc_registered_at').not_byos
    @logger.info(_('Syncing %{count} updated system(s) to SCC') % { count: systems.size })

    begin
      updated_systems = scc_api_client.send_bulk_system_update(systems)
    rescue StandardError => e
      @logger.error(_('Failed to sync systems: %{error}') % { error: e.to_s })
    else
      failed_scc_synced_systems = systems.pluck(:login).excluding(updated_systems[:systems].pluck(:login))
      if failed_scc_synced_systems.present?
        # The response from SCC will be 201 even if some single systems failed to save.
        @logger.info(_("Couldn't sync %{count} systems.") % { count: failed_scc_synced_systems.count })
      end

      updated_systems[:systems].each do |system_hash|
        # In RMT - SCC communication, RMT's system id is used as token, see also lib/suse/connect/api.rb:108
        system = if system_hash[:system_token]
                   System.find_by(id: system_hash[:system_token])
                 else
                   System.find_by(login: system_hash[:login])
                 end
        system.update_columns(
          scc_system_id: system_hash[:id],
          scc_synced_at: Time.current
        )
      end
    end
    DeregisteredSystem.find_in_batches(batch_size: 20) do |batch|
      batch.each do |deregistered_system|
        @logger.info(
          _('Syncing de-registered system %{scc_system_id} to SCC') % {
            scc_system_id: deregistered_system.scc_system_id
          }
        )
        scc_api_client.forward_system_deregistration(deregistered_system.scc_system_id)
        deregistered_system.destroy!
      end
    end
  end

  protected

  def credentials_set?
    Settings.try(:scc).try(:username) && Settings.try(:scc).try(:password)
  end

  def update_repositories(repos)
    @logger.info _('Updating repositories')
    repos.each do |repo|
      repository_service.update_repository!(repo)
    end
  end

  def update_subscriptions(subscriptions)
    @logger.info _('Updating subscriptions')
    subscriptions.each do |item|
      subscription = Subscription.find_or_create_by(id: item[:id])
      subscription.attributes = item.select { |k, _| subscription.attributes.keys.member?(k.to_s) }
      subscription.kind = item[:type]
      subscription.save!

      item[:product_classes].each do |item_class|
        SubscriptionProductClass.find_or_create_by(subscription_id: subscription.id, product_class: item_class)
      end
    end
  end

  def get_product(id)
    Product.find_or_create_by(id: id)
  end

  def create_product(item, root_product_id = nil, base_product = nil, recommended = false, migration_extra = false)
    ActiveRecord::Base.transaction do
      @logger.debug _('Adding/Updating product %{product}') % { product: "#{item[:identifier]}/#{item[:version]}#{(item[:arch]) ? '/' + item[:arch] : ''}" }

      product = get_product(item[:id])
      product.attributes = item.select { |k, _| product.attributes.keys.member?(k.to_s) }
      product.save!

      create_service(item, product)

      if root_product_id
        ProductsExtensionsAssociation.create(
          product_id: base_product,
          extension_id: product.id,
          root_product_id: root_product_id,
          recommended: recommended,
          migration_extra: migration_extra
        )
      else
        root_product_id = product.id
        ProductsExtensionsAssociation.where(root_product_id: root_product_id).destroy_all
      end

      item[:extensions].each do |ext_item|
        create_product(ext_item, root_product_id, product.id, ext_item[:recommended], ext_item[:migration_extra])
      end
    end
  end

  def create_service(item, product)
    service = product.find_or_create_service!

    item[:repositories].each do |repo_item|
      repository_service.update_or_create_repository!(product, repo_item[:url], repo_item)
    end

    # detect repositories removed from the product in SCC
    removed_repos = service.repositories.only_scc.where.not(scc_id: item[:repositories].pluck(:id))
    disassociate_repositories(service, removed_repos) if removed_repos.present?

  end

  def disassociate_repositories(service, repos)
    service.repositories.delete(repos)
    @logger.debug("Removed repositories #{repos.pluck(:scc_id)} from '#{service.product.friendly_name}'")
  end

  def migration_paths(item)
    product = get_product(item[:id])
    ProductPredecessorAssociation.where(product_id: product.id).destroy_all
    create_migration_path(product, item[:online_predecessor_ids], :online) unless item[:online_predecessor_ids].empty?
    create_migration_path(product, item[:offline_predecessor_ids], :offline) unless item[:offline_predecessor_ids].empty?
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
