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

  desc 'mirror', 'Mirror repositories'
  # long_desc <<-LONGDESC
  #   If no REPOSITORY_URL is given, will mirror all repositories that are marked for mirroring in the DB.
  #
  #   If REPOSITORY_URL is given, mirrors only the repository at the specified URL.
  #   LOCAL_PATH can optionally be specified to modify mirroring directory path.
  # LONGDESC
  option :to_dir, desc: 'Mirror to another directory'
  option :from_dir, desc: 'Mirror from a directory instead of SCC'
  def mirror #(repository_url = nil, local_path = nil)
    repository_url = nil
    local_path     = nil

    if options.from_dir
      RMT::Mirror.rsync(from_dir: options.from_dir, to_dir: options.to_dir)
    else
      RMT::CLI::Base.handle_exceptions do
        RMT::CLI::Mirror.mirror(repository_url, local_path, options.to_dir)
      end
    end
  end

  desc 'version', 'Show RMT version'
  def version
    puts RMT::VERSION
  end

  map %w[--version -v] => :version

end
