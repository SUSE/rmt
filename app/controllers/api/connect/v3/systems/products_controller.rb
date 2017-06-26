class Api::Connect::V3::Systems::ProductsController < Api::Connect::BaseController

  before_action :authenticate_system
  before_action :require_product, only: [:show, :activate]
  before_action :check_base_product_dependencies, only: [:activate, :upgrade, :show]

  def activate
    create_product_activation
    render_service
  end

  def show
    unless @system.products.include? @product
      untranslated = N_("The requested product '%s' is not activated on this system." % @product.friendly_name)
      respond_with_error({ message: untranslated, localized_message: _(untranslated) }) and return
    end
    respond_with(
      @product,
      serializer: ::V3::ProductSerializer,
      uri_options: { scheme: request.scheme, host: request.host, port: request.port },
      service_url: url_for(controller: '/services', action: :show, id: @product.service.id)
    )
  end

  protected

  def require_product
    require_params([:identifier, :version, :arch])

    @product = Product.where(identifier: params[:identifier], version: params[:version], arch: params[:arch]).first

    unless @product
      message = N_('No product found')
      respond_with_error({ message: message, localized_message: _(message) }) and return
    end
    check_product_service_and_repositories
  end

  def check_product_service_and_repositories
    unless @product.service && @product.repositories.present?
      fail ActionController::TranslatedError.new(
        error:          N_('No repositories found for product: %s') % @product.friendly_name,
        localized_error: _('No repositories found for product: %s') % @product.friendly_name
      )
    end
  end

  def create_product_activation
    Activation.where(
      system_id: @system.id,
      service_id: @product.service.id
    ).first_or_create
  end

  # Check if extension base product is already activated
  def check_base_product_dependencies
    # TODO: For APIv5 and future. We skip this check for second level extensions. E.g. HA-GEO
    # To fix bnc#951189 specifically the rollback part of it.
    return if @product.bases.any?(&:extension?)
    return if @product.base? || !(@system.products & @product.bases).blank?

    logger.info(N_("Tried to activate/upgrade to '%s' with unmet base product dependency") % @product.friendly_name)
    untranslated = 'Unmet product dependencies, please activate one of these products first: %s' % @product.bases.map(&:friendly_name).join(', ')
    respond_with_error({ message: untranslated, localized_message: _(untranslated) }) and return
  end

  def render_service
    status = ((request.put? || request.post?) ? 201 : 200)
    # manually setting request method, so respond_with actually renders content also for PUT
    request.instance_variable_set(:@request_method, 'GET')

    respond_with(
      @product.service,
      serializer: ::V3::ServiceSerializer,
      uri_options: { scheme: request.scheme, host: request.host, port: request.port },
      obsoleted_service_name: @obsoleted_service_name,
      status: status,
      service_url: url_for(controller: '/services', action: :show, id: @product.service.id)
    )
  end

end
