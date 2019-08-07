class Api::Connect::V4::Repositories::InstallerController < Api::Connect::BaseController

  def index
    require_params(%i[identifier version arch])
    product = Product.find_by(product_params)

    if product
      respond_with ActiveModel::Serializer::CollectionSerializer.new(
        product.repositories.only_installer_updates.only_mirrored,
        serializer: ::V3::RepositorySerializer,
        base_url: request.base_url
      )
    else
      product_name = product_params.values.join(' ').squish
      raise ActionController::TranslatedError.new(
        N_('No product found on RMT for: %s'),
        product_name
      )
    end
  end

  private

  def product_params
    hash = params.permit(:identifier, :version, :arch, :release_type)
    hash[:release_type] = nil if hash[:release_type].blank?
    hash[:version] = Product.clean_up_version(hash[:version])
    hash.to_h.symbolize_keys
  end

end
