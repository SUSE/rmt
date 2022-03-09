class RMT::CLI::Repos < RMT::CLI::ReposBase

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

  desc 'clean', _('Removes locally mirrored files of repositories which are not marked to be mirrored')
  option :non_interactive, aliases: '-n', type: :boolean, desc: _(' Don\'t require user interaction. Default: Auto accept confirmation dialog.')

  def clean
    base_directory = RMT::DEFAULT_MIRROR_DIR

    repos_to_delete = Repository.where(mirroring_enabled: false).map do |repo|
      repository_dir = File.join(base_directory, repo.local_path)
      Dir.exist?(repository_dir) ? repo : nil
    end.compact

    if repos_to_delete.empty?
      puts _('RMT only found locally mirrored files of repositories that are marked to be mirrored.')
      return
    end

    puts _('RMT found locally mirrored files from the following repositories which are not marked to be mirrored:')
    print "\n\e[31m"
    repos_to_delete.each do |repo|
      puts repo.description
    end
    print "\n\e[0m\e[1m"
    print _('Would you like to continue and remove the locally mirrored files of these repositories?')
    print "\n\e[22m\s\s"
    print _("Only '%{input}' will be accepted.") % { input: 'yes' }
    print "\n\n\s\s\e[1m"
    print _('Enter a value:')
    print "\e[22m\s\s"

    unless options[:non_interactive]
      input = $stdin.gets.to_s.strip
      if input != 'yes'
        puts "\n" + _('Clean cancelled.')
        return
      end
    end

    print "\n"
    total_size = 0
    repos_to_delete.each do |repo|
      puts _("Deleting locally mirrored files from repository '%{repo}'...") % { repo: repo.description }
      path = File.join(base_directory, repo.local_path)
      downloaded_files = DownloadedFile.where('local_path LIKE ?', "#{path}%")
      total_size += downloaded_files.sum(:file_size)
      FileUtils.rm_r(path, secure: true)
      downloaded_files.destroy_all
    end

    print "\n\e[32m"
    print _('Clean finished. An estimated %{total_file_size} was removed.') % { total_file_size: ActiveSupport::NumberHelper.number_to_human_size(total_size) }
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
    repositories = ((scope == :all) ? Repository.only_scc : Repository.only_scc.only_mirroring_enabled).order(:name, :description)
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

end
