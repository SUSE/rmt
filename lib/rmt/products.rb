require 'rmt'

# rubocop:disable Rails/Output

class RMT::Products < RMT::Thor

  desc 'list', 'List all products'
  def list
    attributes = %i[id name version release_stage mirrored?]
    headings = ['ID', 'Name', 'Version', 'Release stage', 'Mirrored?']

    conditions = {}

    rows = Product.where(conditions).map do |product|
      attributes.map { |a| product.public_send(a) }
    end

    puts Terminal::Table.new headings: headings, rows: rows
  end

end
