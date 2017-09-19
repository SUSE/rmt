class RMT::Products < RMT::Thor

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

end
