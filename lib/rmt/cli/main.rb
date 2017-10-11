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

  desc 'mirror [REPOSITORY_URL [LOCAL_PATH]]', 'Mirror repositories'
  long_desc <<-LONGDESC
    If no REPOSITORY_URL is given, will mirror all repositories that are marked for mirroring in the DB.

    If REPOSITORY_URL is given, mirrors only the repository at the specified URL.
    LOCAL_PATH can optionally be specified to modify mirroring directory path.
  LONGDESC
  def mirror(repository_url = nil, local_path = nil)
    RMT::CLI::Base.handle_exceptions { RMT::CLI::Mirror.mirror(repository_url, local_path) }
  end

  desc 'version', 'Show RMT version'
  def version
    puts RMT::VERSION
  end

  map %w[--version -v] => :version

end
