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

end
