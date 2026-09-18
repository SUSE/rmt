require 'base64'
require 'json'

module SccSumaApi
  REPOSITORY_URL = 'https://scc.suse.com/suma/'.freeze
  CACHED_PRODUCT_TREE_JSON = '/usr/share/rmt/public/suma/product_tree.json'.freeze

  # products included with an MLM subscription that no product class grants
  # the MLM products themselves and the client tools MLM serves to its clients
  # These are the only products resolved by identifier rather than by class
  MLM_PRODUCT_IDENTIFIERS = %w[
    SUSE-Manager-Server
    SUSE-Manager-Proxy
    SUSE-Manager-Retail-Branch-Server
    SUSE-Multi-Linux-Manager-Server
    SUSE-Multi-Linux-Manager-Proxy
  ].freeze

  CLIENT_TOOLS_PRODUCT_IDENTIFIERS = %w[
    SLE-Manager-Tools
    SUSE-Manager-Tools
  ].freeze

  class SccSumaApiController < ::ApplicationController
    before_action :is_valid?, only: %w[unscoped_products repos]

    def unscoped_products
      update_cache unless cache_is_valid?

      unscoped_products_json = File.read(@unscoped_products_path)
      render status: :ok, json: JSON.parse(unscoped_products_json)
    end

    def repos
      render status: :ok, json: entitled_repositories.map { |repository| repository_json(repository) }
    end

    def list
      render status: :ok, json: []
    end

    def product_tree
      render status: :ok, json: product_tree_json
    end

    protected

    def scc_client
      @scc_api_client = SUSE::Connect::Api.new(
        Settings.scc.username,
        Settings.scc.password
      )
    end

    def instance_data
      @instance_data ||= Base64.decode64(request.headers['X-Instance-Data'].to_s)
    end

    def product_hash
      {
        identifier: request.headers['X-INSTANCE-IDENTIFIER'],
        version: request.headers['X-INSTANCE-VERSION'],
        arch: request.headers['X-INSTANCE-ARCH']
      }
    end

    def verification_provider
      @verification_provider ||= InstanceVerification.provider.new(
        logger,
        request,
        product_hash,
        instance_data
        )
    end

    def is_valid?
      # check auth for registered BYOS systems
      iid = verification_provider.parse_instance_data
      # at this point, we do not know nor is available the login information of the system
      # so querying the instance ID, which is a unique value, to fetch the system
      systems_found = System.find_by(system_token: iid['instanceId'], proxy_byos_mode: :byos)

      raise 'Unspecified error' unless systems_found.present? || verification_provider.instance_valid?
    rescue InstanceVerification::Exception => e
      logger.error "Could not check if instance metadata '#{instance_data}' is valid: #{e.message}"
      error = ActionController::TranslatedError.new(N_(e.message))
      error.status = :unprocessable_content
      raise error
    end

    # repos this update server can actually serve for the caller's entitled products
    # SCC-sourced (so scc_id is never null), flagged for mirroring, and mirrored at least once
    def entitled_repositories
      product_ids = entitled_product_ids
      return [] if product_ids.empty?

      Repository
        .only_scc
        .only_fully_mirrored
        .joins(:services)
        .where(services: { product_id: product_ids })
        .distinct
        .order(:scc_id)
    rescue StandardError => e
      logger.error("Could not resolve the entitled repositories: #{e.message}")
      []
    end

    def entitled_product_ids
      Product
        .where(product_class: entitled_product_classes)
        .or(Product.where(identifier: MLM_PRODUCT_IDENTIFIERS + CLIENT_TOOLS_PRODUCT_IDENTIFIERS))
        .pluck(:id)
    end

    # pivot through the caller's subscriptions
    # the MLM product class grants a subscription, and
    # that subscription grants every product class the caller is entitled to,
    # including the versions covered by it, which cannot be
    # expressed by matching product identifiers or versions
    def entitled_product_classes
      product_class = caller_product_class

      if product_class.blank?
        logger.error('Could not determine the product class of the caller, returning client tools only')
        return []
      end

      subscription_ids = Subscription
        .joins(:product_classes)
        .where(subscription_product_classes: { product_class: product_class })
        .pluck(:id)

      if subscription_ids.empty?
        logger.error("No subscription grants the product class '#{product_class}'")
        return []
      end

      SubscriptionProductClass.where(subscription_id: subscription_ids).distinct.pluck(:product_class)
    end

    def caller_product_class
      # add_on, if present, is the real product class
      # the MLM base product is Micro (5.1 and older) or SLES 15 SP7 (5.2), and
      # neither of those product classes carries the MLM entitlement
      add_on = verification_provider.add_on
      return add_on if add_on.present?

      base_product&.product_class
    rescue InstanceVerification::Exception => e
      logger.error("Could not determine the add-on product class: #{e.message}")
      base_product&.product_class
    end

    def base_product
      @base_product ||= Product.find_by(
        identifier: request.headers['X-INSTANCE-IDENTIFIER'],
        version: Product.clean_up_version(request.headers['X-INSTANCE-VERSION']),
        arch: request.headers['X-INSTANCE-ARCH']
      )
    end

    def repository_json(repository)
      {
        id: repository.scc_id,
        name: repository.name,
        description: repository.description,
        url: repository_url(repository),
        enabled: repository.enabled,
        autorefresh: repository.autorefresh,
        installer_updates: repository.installer_updates
      }
    end

    def repository_url(repository)
      # built here instead of through RMT::Misc.make_repo_url: in the public cloud,
      # zypper_auth monkey-patches that helper to return a plugin:/susecloud URL,
      # which zypper understands and MLM does not
      File.join(request.base_url, RMT::DEFAULT_MIRROR_URL_PREFIX, repository.local_path)
    end

    def product_tree_json
      product_tree_file_path = CACHED_PRODUCT_TREE_JSON
      unless File.exist?(product_tree_file_path)
        product_tree_file_path.nil?
        download_file_from_scc
        product_tree_file_path = @product_tree_file.local_path
      end

      JSON.parse(File.read(product_tree_file_path))
    end

    def download_file_from_scc
      tmp_dir = Rails.root.join('tmp')
      downloading_paths = {
        base_url: URI.join(REPOSITORY_URL),
        base_dir: tmp_dir,
        cache_dir: tmp_dir
      }
      @product_tree_file = RMT::Mirror::FileReference.new(relative_path: 'product_tree.json', **downloading_paths)

      downloader = RMT::Downloader.new(logger: logger, track_files: false)
      logger.info _('Downloading SUSE Manager product tree to %{dir}') % { dir: tmp_dir }
      downloader.download_multi([@product_tree_file])
    end

    def cache_is_valid?
      @unscoped_products_path = Rails.root.join('tmp/unscoped_products.json')

      return false unless File.exist?(@unscoped_products_path)

      File.new(@unscoped_products_path).ctime > 1.day.ago
    end

    def update_cache
      scc_client
      unscoped_products_json = @scc_api_client.list_products_unscoped.to_json
      File.write(@unscoped_products_path, unscoped_products_json)
    end
  end
end
