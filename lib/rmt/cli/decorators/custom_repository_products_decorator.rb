class RMT::CLI::Decorators::CustomRepositoryProductsDecorator < RMT::CLI::Decorators::Base

  def initialize(products)
    @products = products
  end

  def to_csv
    data = @products.map do |product|
      [
        product.id,
        product.name,
        product.safe_friendly_version,
        product.arch
      ]
    end
    array_to_csv(data, [
      _('ID'),
      _('Name'),
      _('Version'),
      _('Architecture')
    ])
  end

  def to_table
    data = @products.map do |product|
      [
        product.id,
        product.name,
        product.safe_friendly_version,
        product.arch
      ]
    end
    array_to_table(data, [
      _('Product ID'),
      _('Product Name'),
      _('Product Version'),
      _('Product Architecture')
    ])
  end

end
