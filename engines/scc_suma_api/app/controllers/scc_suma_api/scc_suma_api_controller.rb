require 'base64'
require 'json'

module SccSumaApi
  REPOSITORY_URL = 'https://scc.suse.com/suma/'.freeze
  CACHED_PRODUCT_TREE_JSON = '/usr/share/rmt/public/suma/product_tree.json'.freeze

  # same pattern StrictAuthentication uses to allow access to those repositories
  # Manager Server, Proxy, Retail Branch Server and the client tools. Their
  # product classes are granted by subscriptions, but only ever the caller's own
  # version, so an MLM server cannot reach the other versions it redistributes
  # through the pivot. Applied only to callers that are an MLM server, the same
  # condition StrictAuthentication#all_allowed_paths gates its expansion on
  MLM_PRODUCT_IDENTIFIER_PATTERN = '%manager%'.freeze

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

    # repos this update server can actually serve for the caller's
    # entitled products: SCC-sourced (so scc_id is never null), flagged for
    # mirroring, and mirrored at least once
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

    # an MLM subscription grants alpha and beta product classes alongside the
    # released ones (7261-BETA, SLE-M-T-ALPHA, OPENSUSE-ALPHA and so on), so the
    # release stage has to be constrained explicitly: MLM must not be handed
    # pre-release channels for its clients
    #
    # mirrors StrictAuthentication#all_allowed_paths, which decides what an MLM
    # server may download, so the advertised channels and the paths the auth layer
    # permits stay in agreement. Expressed over the caller's entitled products
    # instead of a registered system's activations
    def entitled_product_ids
      ids = subscribed_product_ids
      ids += free_module_product_ids if micro_caller?
      ids += mlm_product_ids if mlm_caller?
      ids.uniq
    end

    # a product class is version independent: SLES 15 SP5, SP6 and SP7 all carry
    # product class 7261. Selecting products by class therefore already returns
    # every version the subscription covers, without RMT hardcoding version
    # numbers, so this needs no equivalent of the version expansion
    # StrictAuthentication#all_allowed_paths does over a system's activations
    def subscribed_product_ids
      product_classes = entitled_product_classes
      return [] if product_classes.empty?

      Product
        .where(product_class: product_classes)
        .with_release_stage('released')
        .pluck(:id)
    end

    # MLM 5.1 and older run on Micro, which is entitled to the free SLES modules
    # of its own arch. Those modules all share the generic 'MODULE' product class,
    # and no subscription lists that class, so resolving entitlement through the
    # caller's subscriptions can never reach them and they have to be selected by
    # identifier instead. SAP modules are excluded, they are not part of the free entitlement.
    # Same case as the sle_micro branch of StrictAuthentication#all_allowed_paths
    def free_module_product_ids
      Product
        .where("lower(identifier) LIKE 'sle-module%' OR lower(identifier) = 'packagehub'")
        .where.not("lower(identifier) LIKE '%sap%'")
        .where(arch: request.headers['X-INSTANCE-ARCH'], free: true)
        .with_release_stage('released')
        .pluck(:id)
    end

    def mlm_product_ids
      Product
        .where('identifier LIKE ?', MLM_PRODUCT_IDENTIFIER_PATTERN)
        .with_release_stage('released')
        .pluck(:id)
    end

    def micro_caller?
      request.headers['X-INSTANCE-IDENTIFIER'].to_s.downcase.include?('micro')
    end

    # the caller's add-on class belongs to a Manager product, so the caller is an
    # MLM server and the channels it redistributes are part of its entitlement
    def mlm_caller?
      return false if caller_product_class.blank?

      Product
        .where(product_class: caller_product_class)
        .exists?(['identifier LIKE ?', MLM_PRODUCT_IDENTIFIER_PATTERN])
    end

    # resolve the caller's entitlement from the synced subscription data: the
    # add-on product class identifies which subscriptions grant it, and each of
    # those subscriptions lists every product class it covers. Those classes are
    # the entitlement. They are also the only record of which versions the
    # subscription covers, so the same answer cannot be reconstructed by matching
    # product identifiers or version numbers
    def entitled_product_classes
      product_class = caller_product_class

      if product_class.blank?
        logger.error('Could not determine the product class of the caller, no entitlement can be resolved')
        return []
      end

      # the subscription table being queried
      # has public cloud subscritions only
      subscription_ids = Subscription
        .active
        .not_expired
        .joins(:product_classes)
        .where(subscription_product_classes: { product_class: product_class })
        .pluck(:id)

      if subscription_ids.empty?
        logger.error("No subscription grants the product class '#{product_class}'")
        return []
      end

      SubscriptionProductClass.where(subscription_id: subscription_ids).distinct.pluck(:product_class)
    end

    # add_on is the only product class that carries the MLM entitlement. The MLM
    # base product is Micro (5.1 and older) or SLES 15 SP7 (5.2), and neither of
    # those classes carries it, so there is deliberately no fallback to the base
    # product class: nearly every subscription lists it, and resolving entitlement
    # through it would hand back the organisation's whole catalogue
    # A blank result means no subscription entitlement can be resolved for this caller
    def caller_product_class
      return @caller_product_class if defined?(@caller_product_class)

      @caller_product_class = verification_provider.add_on.presence
    rescue InstanceVerification::Exception => e
      logger.error("Could not determine the add-on product class: #{e.message}")
      @caller_product_class = nil
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
      # Built here instead of through RMT::Misc.make_repo_url: in the public
      # cloud, zypper_auth monkey-patches that helper to return a
      # plugin:/susecloud URL, which zypper understands and MLM does not.
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
