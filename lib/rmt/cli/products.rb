class RMT::CLI::Products < RMT::CLI::Base

  desc 'list', 'List all products'
  option :release_stage, aliases: '-r', type: :string
  def list
    attributes = %i[id name version release_stage mirrored?]
    headings = ['ID', 'Name', 'Version', 'Release stage', 'Mirrored?']

    conditions = options[:release_stage] ? { release_stage: options[:release_stage] } : {}

    rows = Product.where(conditions).map do |product|
      attributes.map { |a| product.public_send(a) }
    end

    puts Terminal::Table.new headings: headings, rows: rows # rubocop:disable Rails/Output
  end

  desc 'enable', 'Enable a product'
  def enable
    # TODO: should behave the same as 'repos enable [product_identifier]'
  end

  desc 'disable', 'Disable a product'
  def enable
    # TODO: should behave the same as 'repos disable [product_identifier]'
  end
end
