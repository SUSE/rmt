class RMT::CLI::ReposBase < RMT::CLI::Base

  class RepoNotFoundException < StandardError
  end

  protected

  def change_repos(ids, set_enabled, custom: false)
    ids = clean_target_input(ids)
    raise RMT::CLI::Error.new(_('No repository ids supplied')) if ids.empty?

    failed_repos = []
    ids.each do |id|
      change_repo(id, set_enabled, custom: custom)
    rescue RepoNotFoundException => e
      warn e.message
      failed_repos << id
    end

    unless failed_repos.empty?
      message = if set_enabled
                  n_('Repository by ID %{repos} could not be found and was not enabled.',
                     'Repositories by IDs %{repos} could not be found and were not enabled.',
                     failed_repos.count) % { repos: failed_repos.join(', ') }
                else
                  n_('Repository by ID %{repos} could not be found and was not disabled.',
                     'Repositories by IDs %{repos} could not be found and were not disabled.',
                     failed_repos.count) % { repos: failed_repos.join(', ') }
                end
      raise RMT::CLI::Error.new(message)
    end
  end

  def change_repo(id, set_enabled, custom: false)
    repository = find_repository!(id, custom: custom)
    repository.change_mirroring!(set_enabled)

    puts set_enabled ? _('Repository by ID %{id} successfully enabled.') % { id: id } : _('Repository by ID %{id} successfully disabled.') % { id: id }
  end

  def is_numeric_id?(str)
    # Check if given string is a plain number without any additional characters
    # like '15sp3-ptf-repo-id'.
    Integer(str) rescue false
  end

  def find_repository!(id, custom: false)
    # allow fallback for old IDs when dealing with custom repos
    if is_numeric_id?(id) && custom
      repository = Repository.find_by(id: id)
    end

    repository ||= Repository.find_by(friendly_id: id)

    if repository.nil? || (custom && !repository.custom?)
      raise RepoNotFoundException.new(_('Repository by ID %{id} not found.') % { id: id })
    end

    repository
  end
end
