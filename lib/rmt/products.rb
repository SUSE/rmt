require 'rmt'
require 'rmt/cli'

# rubocop:disable Rails/Output

class RMT::Products < RMT::CLI

  desc 'list', 'List all products'
  option :all, aliases: '-a', type: :boolean
  option :repository_status, aliases: '-r', type: :boolean
  def list
    attributes = %i[id name version release_stage]
    headings = ['ID', 'Name', 'Version', 'State']

    if options['repository_status']
      attributes.push(:mirrored)
      headings.push('Repository Status')
    end

    scope = options['all'] ? :all : :published

    rows = Product.public_send(scope).map do |product|
      attributes.map { |a| product.public_send(a) }
    end

    puts Terminal::Table.new headings: headings, rows: rows
  end

end
