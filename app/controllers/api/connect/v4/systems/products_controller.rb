class Api::Connect::V4::Systems::ProductsController < Api::Connect::V3::Systems::ProductsController

  def destroy
    if @product.base?
      raise ActionController::TranslatedError.new(N_('The product "%s" is a base product and cannot be deactivated'), @product.name)
    elsif @system.activations.joins(:product).where(products: { id: @product.extension_ids }).any?
      raise ActionController::TranslatedError.new(N_('Cannot deactivate the product "%s". Other activated products depend upon it.'), @product.name)
    else
      @activation = @system.activations.find_by!(service_id: @product.service.id)
      @activation.destroy
      logger.info("Product '#{@product.friendly_name}' deactivated")
      render_service
    end
  rescue ActiveRecord::RecordNotFound
    raise ActionController::TranslatedError.new(N_('%s is not yet activated on the system.'), @product.name)
  end

  def synchronize
    products = params.require(:products).map do |product_params|
      @system.products.find_by(
        identifier: product_params[:identifier],
        version: Product.clean_up_version(product_params[:version]),
        arch: product_params[:arch]
      )
    end

    ActiveRecord::Base.transaction do
      (@system.products - products).each do |product|
        @system.activations.includes(:service).find_by('services.product_id' => product.id).destroy
        logger.info("Product '%s' de-activated on system %s" % [product.friendly_name, @system.id])
      end
    end

    render json: @system.products.reload,
      each_serializer: ::V3::ProductSerializer,
      base_url: URI::HTTP.build({ scheme: response.request.scheme, host: response.request.host })
  end

end
