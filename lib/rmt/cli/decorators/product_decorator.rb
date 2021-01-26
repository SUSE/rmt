class RMT::CLI::Decorators::ProductDecorator < RMT::CLI::Decorators::Base

  def initialize(products)
    @products = products
  end

  def to_csv
    data = @products.map do |product|
      [
        product.id,
        product.shortname,
        product.safe_friendly_version,
        product.arch,
        product.product_string,
        product.release_stage,
        product.mirror?,
        product.last_mirrored_at
      ]
    end
    array_to_csv(data, [
      _('ID'),
      _('Product'),
      _('Version'),
      _('Arch'),
      _('Product String'),
      _('Release Stage'),
      _('Mirror?'),
      _('Last mirrored')
    ])
  end

  def to_table
    data = @products.map do |product|
      [
        product.id,
        "#{product.name}\n#{product.product_string}",
        product.safe_friendly_version,
        product.arch,
        product.mirror? ? _('Mirror') : _("Don't Mirror"),
        product.last_mirrored_at
      ]
    end
    array_to_table(data, [
      _('ID'),
      _('Product'),
      _('Version'),
      # i18n: architecture
      _('Arch'),
      _('Mirror?'),
      _('Last mirrored')
    ])
  end

end
