require 'thor'

require 'rmt'
require 'rmt/products'
require 'rmt/repo_manager'
require 'rmt/products'
require 'rmt/scc_sync'
require 'terminal-table'

class RMT::CLI < RMT::Thor

  class_option :debug, desc: 'Enable debug output', aliases: '-d', required: false

  desc 'products', 'List and modify products'
  subcommand 'products', RMT::Products

  desc 'repos', 'List and modify repositories'
  subcommand 'repos', RMT::RepoManager

  desc 'scc', 'SUSE Customer Center commands'
  subcommand 'scc', RMT::SCCSync

end
