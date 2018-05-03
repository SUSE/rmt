require 'thor'
require 'terminal-table'

class RMT::CLI::Main < RMT::CLI::Base

  class_option :debug, desc: 'Enable debug output', type: :boolean, aliases: '-d', required: false

  desc 'sync', 'Sync database with SUSE Customer Center'
  def sync
    RMT::Lockfile.create_file
    RMT::SCC.new(options).sync
    RMT::Lockfile.remove_file
  rescue RMT::Lockfile::ExecutionLockedError
    puts 'Process is locked'
  rescue StandardError
    RMT::Lockfile.remove_file
    raise
  end

  desc 'products', 'List and modify products'
  subcommand 'products', RMT::CLI::Products

  desc 'repos', 'List and modify repositories'
  subcommand 'repos', RMT::CLI::Repos

  desc 'mirror', 'Mirror repositories'
  def mirror
    RMT::Lockfile.create_file
    repos = Repository.where(mirroring_enabled: true)
    if repos.empty?
      warn 'There are no repositories marked for mirroring.'
      return
    end
    repos.each { |repo| mirror!(repo) }
    RMT::Lockfile.remove_file
  rescue RMT::Lockfile::ExecutionLockedError
    puts 'Process is locked'
  rescue StandardError
    RMT::Lockfile.remove_file
    raise
  end

  desc 'import', 'Import commands for Offline Sync'
  subcommand 'import', RMT::CLI::Import

  desc 'export', 'Export commands for Offline Sync'
  subcommand 'export', RMT::CLI::Export

  desc 'version', 'Show RMT version'
  def version
    puts RMT::VERSION
  end

  map %w[--version -v] => :version

end
