class RMT::CLI::Repos < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'custom', 'List and modify custom repositories'
  subcommand 'custom', RMT::CLI::ReposCustom

  desc 'list', 'List repositories which are marked to be mirrored'
  option :all, aliases: '-a', type: :boolean, desc: 'List all repositories, including ones which are not marked to be mirrored'
  def list
    scope = options[:all] ? :all : :enabled
    list_repositories(scope: scope)
  end
  map ls: :list

  desc 'enable TARGET', 'Enable mirroring of repositories by repository ID or product string'
  def enable(target)
    change_mirroring(target, true)
  end

  desc 'disable TARGET', 'Disable mirroring of repositories by repository ID or product string'
  def disable(target)
    change_mirroring(target, false)
  end

  protected

  def list_repositories(scope: :enabled)
    repositories = (scope == :all) ? Repository.only_scc : Repository.only_scc.only_mirrored

    if repositories.empty?
      if options.all
        warn 'Run "rmt-cli sync" to synchronize with your SUSE Customer Center data first.'
      else
        warn 'No repositories enabled.'
      end
    else
      puts array_to_table(repositories, {
        scc_id: 'SCC ID',
        name: 'Name',
        description: 'Description',
        enabled: 'Mandatory?',
        mirroring_enabled: 'Mirror?',
        last_mirrored_at: 'Last mirrored'
      })
    end
  end

  private

  def change_mirroring(target, set_enabled)
    repository_service.change_repository_mirroring!(target, set_enabled)
    puts "Repository successfully #{set_enabled ? 'enabled' : 'disabled'}."
  rescue RepositoryService::RepositoryNotFound => e
    raise RMT::CLI::Error.new(e.message)
  end

  def repository_service
    @repository_service ||= RepositoryService.new
  end

end
