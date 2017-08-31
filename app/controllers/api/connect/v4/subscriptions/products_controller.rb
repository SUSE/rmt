class Api::Connect::V4::Subscriptions::ProductsController < Api::Connect::BaseController

  before_action :authenticate_with_token

  def index
    products = @subscription.products.where(product_query_params)
    respond_with(
      products,
      each_serializer: ::V3::ProductSerializer,
      base_url: request.base_url,
      expires_at: 12.hours.from_now
    )
  end

  private

  def product_query_params
    {
      identifier: product_params[:identifier],
      version: Product.clean_up_version(product_params[:version]),
      arch: product_params[:arch],
      release_type: product_params[:release_type]
    }.compact
  end

  def product_params
    params.permit(:identifier, :version, :arch, :release_type)
  end

end
