require 'thor'

class RMT::CLI::Main < RMT::CLI::Base

  class_option :debug, desc: 'Enable debug output', type: :boolean, aliases: '-d', required: false

  desc 'sync', 'Sync database with SUSE Customer Center'
  def sync
    RMT::Lockfile.lock do
      RMT::SCC.new(options).sync
    end
  end

  desc 'products', 'List and modify products'
  subcommand 'products', RMT::CLI::Products

  desc 'repos', 'List and modify repositories'
  subcommand 'repos', RMT::CLI::Repos

  desc 'mirror', 'Mirror repositories'
  def mirror
    RMT::Lockfile.lock do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger)

      repos = Repository.where(mirroring_enabled: true)

      raise RMT::CLI::Error.new('There are no repositories marked for mirroring.') if repos.empty?

      repos.each do |repo|
        begin
          mirror.mirror(
            repository_url: repo.external_url,
            local_path: Repository.make_local_path(repo.external_url),
            auth_token: repo.auth_token,
            repo_name: repo.name
          )

          repo.refresh_timestamp!
        rescue RMT::Mirror::Exception => e
          logger.warn e.to_s
        end
      end
    end
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
