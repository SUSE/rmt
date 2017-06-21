class Api::Connect::V4::Systems::ProductsController < Api::Connect::V4::BaseController

  before_action :authenticate_system
  before_action :require_product, only: [:activate]

  def activate
    create_product_activation
    render_service
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
