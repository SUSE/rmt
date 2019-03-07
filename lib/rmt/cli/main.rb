require 'thor'

class RMT::CLI::Main < RMT::CLI::Base

  class_option :debug, desc: _('Enable debug output'), type: :boolean, aliases: '-d', required: false

  desc 'sync', _('Sync database with SUSE Customer Center')
  def sync
    RMT::Lockfile.lock do
      RMT::SCC.new(options).sync
    end
  end

  desc 'products', _('List and modify products')
  subcommand 'products', RMT::CLI::Products

  desc 'repos', _('List and modify repositories')
  subcommand 'repos', RMT::CLI::Repos

  desc 'mirror', _('Mirror repositories')
  def mirror
    RMT::Lockfile.lock do
      logger = RMT::Logger.new(STDOUT)
      mirror = RMT::Mirror.new(logger: logger)

      mirror.mirror_suma_product_tree(repository_url: 'https://scc.suse.com/suma/')

      repos = Repository.where(mirroring_enabled: true)

      raise RMT::CLI::Error.new(_('There are no repositories marked for mirroring.')) if repos.empty?

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

  desc 'import', _('Import commands for Offline Sync')
  subcommand 'import', RMT::CLI::Import

  desc 'export', _('Export commands for Offline Sync')
  subcommand 'export', RMT::CLI::Export

  desc 'version', _('Show RMT version')
  def version
    puts RMT::VERSION
  end

  map %w[--version -v] => :version

end
