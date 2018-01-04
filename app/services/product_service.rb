class ProductService

  def get_service(product)
    Service.find_or_create_by(product_id: product.id)
  end

end
