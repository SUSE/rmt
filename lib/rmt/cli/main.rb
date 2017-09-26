class RMT::CLI::Main < RMT::CLI::Base

  class_option :debug, desc: 'Enable debug output', aliases: '-d', required: false

  desc 'products', 'List and modify products'
  subcommand 'products', RMT::CLI::Products

  desc 'repos', 'List and modify repositories'
  subcommand 'repos', RMT::CLI::Repos

  desc 'scc', 'SUSE Customer Center commands'
  subcommand 'scc', RMT::CLI::SCC

  desc 'mirror', 'Mirror all enabled repositories'
  def mirror
    RMT::CLI::Mirror.mirror
  end

  desc 'version', 'Show RMT version'
  def version
    require 'rmt'
    puts RMT::VERSION # rubocop:disable Rails/Output
  end

end
