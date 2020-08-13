class RMT::CLI::Repos < RMT::CLI::Base

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
  map 'ls' => :list

  desc 'clean', _('Removes un-mirrored repositories from the local disk.')
  def clean
    base_directory = RMT::DEFAULT_MIRROR_DIR

    repos_to_delete = Repository.where(mirroring_enabled: false).map do |repo|
      repository_dir = File.join(base_directory, repo.local_path)
      Dir.exist?(repository_dir) ? repo : nil
    end.compact

    if repos_to_delete.empty?
      puts _('No un-mirrored repositories found on local disk.')
      return
    end

    puts _('RMT found the following un-mirrored repositories:')
    print "\n\e[31m"
    repos_to_delete.each do |repo|
      puts repo.description
    end
    print "\n\e[0m\e[1m"
    print _('Would you like to continue and remove these directories from your local disk?')
    print "\n\e[22m\s\s"
    print _("Only '%{input}' will be accepted.") % { input: 'yes' }
    print "\n\n\s\s\e[1m"
    print _('Enter a value:')
    print "\e[22m\s\s"

    input = $stdin.gets.to_s.strip
    if input != 'yes'
      puts "\n" + _('Clean cancelled.')
      return
    end

    print "\n"
    repos_to_delete.each do |repo|
      path = File.join(base_directory, repo.local_path)
      FileUtils.rm_r(path, secure: true)
      DownloadedFile.where('local_path LIKE ?', "#{path}%").destroy_all
      puts _("Deleted repository '%{repo}'.") % { repo: repo.description }
    end

    print "\n\e[32m"
    print _('Clean finished.')
    print "\e[0m\n"
  end

  desc 'enable IDS', _('Enable mirroring of repositories by a list of repository IDs')
  long_desc <<-REPOS
#{_('Enable mirroring of repositories by a list of repository IDs')}

#{_('Examples:')}

$ rmt-cli repos enable 2526

$ rmt-cli repos enable 2526 3263
REPOS
  def enable(*ids)
    change_repos(ids, true)
  end

  desc 'disable IDS', _('Disable mirroring of repositories by a list of repository IDs')
  long_desc <<-REPOS
#{_('Disable mirroring of repositories by a list of repository IDs')}

#{_('Examples:')}

$ rmt-cli repos disable 2526

$ rmt-cli repos disable 2526 3263
REPOS
  def disable(*ids)
    change_repos(ids, false)

    puts "\n\e[1m" + _("To clean up downloaded files, please run '%{command}'") % { command: 'rmt-cli repos clean' } + "\e[22m"
  end

  protected

  def list_repositories(scope: :enabled)
    repositories = ((scope == :all) ? Repository.only_scc : Repository.only_scc.only_mirrored).order(:name, :description)
    decorator = ::RMT::CLI::Decorators::RepositoryDecorator.new(repositories)

    if repositories.empty?
      if options.all
        warn _("Run '%{command}' to synchronize with your SUSE Customer Center data first.") % { command: 'rmt-cli sync' }
      else
        warn _('No repositories enabled.')
      end
    elsif options.csv
      puts decorator.to_csv
    else
      puts decorator.to_table
    end
    unless options.all || options.csv
      puts _("Only enabled repositories are shown by default. Use the '%{option}' option to see all repositories.") % { option: '--all' }
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

    puts set_enabled ? _('Repository by ID %{id} successfully enabled.') % { id: id } : _('Repository by ID %{id} successfully disabled.') % { id: id }
  rescue ActiveRecord::RecordNotFound
    raise RepoNotFoundException.new(_('Repository not found by ID %{id}.') % { id: id })
  end


end
