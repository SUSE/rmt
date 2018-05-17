class Api::Connect::V3::Systems::ProductsController < Api::Connect::BaseController

  before_action :authenticate_system
  before_action :require_product, only: %i[show activate upgrade destroy]
  before_action :check_product_service_and_repositories, only: %i[show activate]
  before_action :check_base_product_dependencies, only: %i[activate upgrade show]

  def activate
    create_product_activation
    render_service
  end

  def show
    if @system.products.include? @product
      respond_with(
        @product,
        serializer: ::V3::ProductSerializer,
        base_url: request.base_url
      )
    else
      raise ActionController::TranslatedError.new(N_("The requested product '%s' is not activated on this system."), @product.friendly_name)
    end
  end

  def migrations
    require_params([:installed_products])

    begin
      upgrade_paths = MigrationEngine.new(@system, installed_products).online_migrations

      render json: migration_paths_as_json(upgrade_paths)
    rescue MigrationEngine::MigrationEngineError => e
      raise ActionController::TranslatedError.new(e.message, *e.data)
    end
  end

  def offline_migrations
    require_params(%i[installed_products target_base_product])

    begin
      offline_upgrade_paths = MigrationEngine.new(@system, installed_products)
        .offline_migrations(product_from_hash(params[:target_base_product]))

      render json: migration_paths_as_json(offline_upgrade_paths)
    rescue MigrationEngine::MigrationEngineError => e
      raise ActionController::TranslatedError.new(e.message, *e.data)
    end
  end

  def upgrade
    obsoleted_product_ids = ([@product] + @product.predecessors + @product.successors).map(&:id)
    obsoleted_service = @system.services.find_by(product_id: obsoleted_product_ids)
    @obsoleted_service_name = obsoleted_service.name if obsoleted_service

    ActiveRecord::Base.transaction do
      remove_previous_product_activations(obsoleted_product_ids)
      create_product_activation
    end

    render_service
  end

  protected

  def installed_products
    params[:installed_products].map { |hash| product_from_hash(hash) rescue nil }.compact
  end

  def migration_paths_as_json(paths)
    paths.reject(&:empty?).map do |item|
      ActiveModelSerializers::SerializableResource.new(
        item,
        each_serializer: ::V3::UpgradePathItemSerializer
      )
    end.to_json
  end

  def require_product
    require_params(%i[identifier version arch])

    @product = Product.find_by(identifier: params[:identifier], version: Product.clean_up_version(params[:version]), arch: params[:arch])

    unless @product
      raise ActionController::TranslatedError.new(N_('No product found'))
    end
  end

  def check_product_service_and_repositories
    unless @product.service && @product.repositories.present?
      fail ActionController::TranslatedError.new(N_('No repositories found for product: %s'), @product.friendly_name)
    end

    mandatory_repos = @product.repositories.only_enabled
    mirrored_repos = @product.repositories.only_enabled.only_mirrored

    unless (mandatory_repos.size == mirrored_repos.size)
      fail ActionController::TranslatedError.new(N_('Not all mandatory repositories are mirrored for product %s'), @product.friendly_name)
    end
  end

  def create_product_activation
    @system.activations.where(service_id: @product.service.id).first_or_create
  end

  def remove_previous_product_activations(product_ids)
    @system.activations.includes(:product).where('products.id' => product_ids).destroy_all
  end

  # Check if extension base product is already activated
  def check_base_product_dependencies
    # TODO: For APIv5 and future. We skip this check for second level extensions. E.g. HA-GEO
    # To fix bnc#951189 specifically the rollback part of it.
    return if @product.bases.any?(&:extension?)
    return if @product.base? || (@system.products & @product.bases).present?

    logger.info("Tried to activate/upgrade to '#{@product.friendly_name}' with unmet base product dependency")
    raise ActionController::TranslatedError.new(
      N_('Unmet product dependencies, activate one of these products first: %s'),
      @product.bases.map(&:friendly_name).join(', ')
    )
  end

  def render_service
    status = ((request.put? || request.post?) ? 201 : 200)
    # manually setting request method, so respond_with actually renders content also for PUT
    request.instance_variable_set(:@request_method, 'GET')

    respond_with(
      @product.service,
      serializer: ::V3::ServiceSerializer,
      base_url: request.base_url,
      obsoleted_service_name: @obsoleted_service_name,
      status: status
    )
  end

  def product_search_params(product_hash)
    hash = product_hash.permit(:identifier, :version, :arch, :release_type).to_h.symbolize_keys
    hash[:version] = Product.clean_up_version(hash[:version])
    hash
  end

  def product_from_hash(product_hash)
    Product.find_by(product_search_params(product_hash))
  end

end
