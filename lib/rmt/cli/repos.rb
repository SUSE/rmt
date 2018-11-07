class RMT::CLI::Repos < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  desc 'custom', _('List and modify custom repositories')
  subcommand 'custom', RMT::CLI::ReposCustom

  desc 'list', _('List repositories which are marked to be mirrored')
  option :all, aliases: '-a', type: :boolean, desc: _('List all repositories, including ones which are not marked to be mirrored')
  option :csv, type: :boolean, desc: _('Output data in CSV format')

  def list
    scope = options[:all] ? :all : :enabled
    list_repositories(scope: scope)
  end
  map ls: :list

  desc 'enable ID', _('Enable mirroring of repositories by repository ID')
  def enable(id)
    change_mirroring(id, true)
  end

  desc 'disable ID', _('Disable mirroring of repositories by repository ID')
  def disable(id)
    change_mirroring(id, false)
  end

  protected

  def list_repositories(scope: :enabled)
    repositories = ((scope == :all) ? Repository.only_scc : Repository.only_scc.only_mirrored).order(:name, :description)

    if repositories.empty?
      if options.all
        warn _('Run `%{command}` to synchronize with your SUSE Customer Center data first.') % { command: 'rmt-cli sync' }
      else
        warn _('No repositories enabled.')
      end
    else
      puts format_array(repositories, {
        scc_id: _('SCC ID'),
        name: _('Name'),
        description: _('Description'),
        enabled: _('Mandatory?'),
        mirroring_enabled: _('Mirror?'),
        last_mirrored_at: _('Last mirrored')
      }, options.csv)
    end
    unless options.all || options.csv
      puts _('Only enabled repositories are shown by default. Use the `%{option}` option to see all repositories.') % { option: '--all' }
    end
  end

  private

  def change_mirroring(id, set_enabled)
    repository = Repository.find_by!(scc_id: id)
    repository.change_mirroring!(set_enabled)

    puts set_enabled ? _('Repository successfully enabled.') : _('Repository successfully disabled.')
  rescue ActiveRecord::RecordNotFound
    raise RMT::CLI::Error.new(_('Repository not found by id "%{id}".') % { id: id })
  end

end
