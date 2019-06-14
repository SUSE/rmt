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

      begin
        mirror.mirror_suma_product_tree(repository_url: 'https://scc.suse.com/suma/')
      rescue RMT::Mirror::Exception => e
        logger.warn(e.message)
      end

      raise RMT::CLI::Error.new(_('There are no repositories marked for mirroring.')) if Repository.where(mirroring_enabled: true).empty?

      mirrored_repo_ids = []
      until Repository.where(mirroring_enabled: true).where.not(id: mirrored_repo_ids).blank?
        repo = Repository.where(mirroring_enabled: true).where.not(id: mirrored_repo_ids).first

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
        ensure
          mirrored_repo_ids << repo.id
        end
      end
    end
  end

  desc 'import', _('Import commands for Offline Sync')
  subcommand 'import', RMT::CLI::Import

  desc 'export', _('Export commands for Offline Sync')
  subcommand 'export', RMT::CLI::Export

  desc 'systems', _('List systems')
  subcommand 'systems', RMT::CLI::Systems

  desc 'version', _('Show RMT version')
  def version
    puts RMT::VERSION
  end

  map %w[--version -v] => :version
  map %w[registration] => :registrations

end
