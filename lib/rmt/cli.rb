class RMT::CLI < RMT::Thor

  class_option :debug, desc: 'Enable debug output', aliases: '-d', required: false

  desc 'products', 'List and modify products'
  subcommand 'products', RMT::Products

  desc 'repos', 'List and modify repositories'
  subcommand 'repos', RMT::RepoManager

  desc 'scc', 'SUSE Customer Center commands'
  subcommand 'scc', RMT::SCCSync

  desc 'mirror', 'Mirror all enabled repositories'
  def mirror
  end

  desc 'version', 'Show RMT version'
  def version
    require 'rmt'
    puts RMT::VERSION # rubocop:disable Rails/Output
  end

end
