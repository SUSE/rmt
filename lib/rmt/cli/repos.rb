class RMT::CLI::Repos < RMT::CLI::Base

  include ::RMT::CLI::ArrayPrintable

  class RepoNotFoundException < StandardError
  end

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

  desc 'enable IDS', _('Enable mirroring of repositories by a list of repository IDs')
  long_desc _(<<-REPOS
Enable mirroring of repositories by a list of repository IDs

Examples:

`rmt-cli repos enable 2526`

`rmt-cli repos enable 2526 3263`

`rmt-cli repos enable 2526,3263`

`rmt-cli repos enable "2526,3263"`
REPOS
)
  def enable(*ids)
    change_repos(ids, true)
  end

  desc 'disable IDS', _('Disable mirroring of repositories by a list of repository IDs')
  long_desc _(<<-REPOS
Disable mirroring of repositories by a list of repository IDs

Examples:

`rmt-cli repos disable 2526`

`rmt-cli repos disable 2526 3263`

`rmt-cli repos disable 2526,3263`

`rmt-cli repos disable "2526,3263"`
REPOS
)
  def disable(*ids)
    change_repos(ids, false)
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
      data = repositories.map do |repo|
        [
          repo.scc_id,
          repo.name,
          repo.description,
          repo.enabled,
          repo.mirroring_enabled,
          repo.last_mirrored_at
        ]
      end

      if options.csv
        puts array_to_csv(data)
      else
        puts array_to_table(data, [
          _('SCC ID'),
          _('Name'),
          _('Description'),
          _('Mandatory?'),
          _('Mirror?'),
          _('Last mirrored')
        ])
      end
    end
    unless options.all || options.csv
      puts _('Only enabled repositories are shown by default. Use the `%{option}` option to see all repositories.') % { option: '--all' }
    end
  end

  def change_repos(ids, set_enabled)
    ids = clean_target_input(ids)
    raise RMT::CLI::Error.new(_('No repository ids supplied')) if ids.empty?

    failed_repos = []
    ids.each do |id|
      change_repo(id, set_enabled)
    rescue RepoNotFoundException => e
      warn e.message
      failed_repos << id
    end

    unless failed_repos.empty?
      message = if set_enabled
                  n_('Repository %{repos} could not be found and was not enabled.',
                     'Repositories %{repos} could not be found and were not enabled.',
                     failed_repos.count) % { repos: failed_repos.join(', ') }
                else
                  n_('Repository %{repos} could not be found and was not disabled.',
                     'Repositories %{repos} could not be found and were not disabled.',
                     failed_repos.count) % { repos: failed_repos.join(', ') }
                end
      raise RMT::CLI::Error.new(message)
    end
  end

  def change_repo(id, set_enabled)
    repository = Repository.find_by!(scc_id: id)
    repository.change_mirroring!(set_enabled)

    puts set_enabled ? _('Repository by id %{id} successfully enabled.') % { id: id } : _('Repository by id %{id} successfully disabled.') % { id: id }
  rescue ActiveRecord::RecordNotFound
    raise RepoNotFoundException.new(_('Repository not found by id "%{id}".') % { id: id })
  end


end
