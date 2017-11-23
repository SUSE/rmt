require 'thor'
require 'terminal-table'

class RMT::CLI::Main < RMT::CLI::Base

  class_option :version, desc: 'Show RMT version', type: :boolean, aliases: '-v', required: false
  class_option :debug, desc: 'Enable debug output', type: :boolean, aliases: '-d', required: false

  desc 'products', 'List and modify products'
  subcommand 'products', RMT::CLI::Products

  desc 'repos', 'List and modify repositories'
  subcommand 'repos', RMT::CLI::Repos

  desc 'scc', 'SUSE Customer Center commands'
  subcommand 'scc', RMT::CLI::SCC

  desc 'mirror', 'Mirror repositories'
  subcommand 'mirror', RMT::CLI::Mirror

  desc 'version', 'Show RMT version'
  def version
    puts RMT::VERSION # rubocop:disable Rails/Output
  end

  map %w[--version -v] => :version

end
