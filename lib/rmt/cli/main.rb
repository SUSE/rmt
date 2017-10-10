require 'thor'
require 'terminal-table'

# rubocop:disable Rails/Output

class RMT::CLI::Main < RMT::CLI::Base

  class_option :version, desc: 'Show RMT version', type: :boolean, aliases: '-v', required: false
  class_option :debug, desc: 'Enable debug output', type: :boolean, aliases: '-d', required: false

  desc 'products', 'List and modify products'
  subcommand 'products', RMT::CLI::Products

  desc 'repos', 'List and modify repositories'
  subcommand 'repos', RMT::CLI::Repos

  desc 'scc', 'SUSE Customer Center commands'
  subcommand 'scc', RMT::CLI::SCC

  desc 'mirror', 'Mirror all enabled repositories'
  def mirror
    RMT::CLI::Base.handle_exceptions { RMT::CLI::Mirror.mirror }
  end

  desc 'version', 'Show RMT version'
  def version
    puts RMT::VERSION
  end

  map %w[--version -v] => :version

end
