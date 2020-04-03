class RMT::CLI::Decorators::RepositoryDecorator < RMT::CLI::Decorators::Base

  def initialize(repositories)
    @repositories = repositories
  end

  def to_csv
    data = @repositories.map do |repo|
      [
        repo.scc_id,
        repo.name,
        repo.description,
        repo.enabled,
        repo.mirroring_enabled,
        repo.last_mirrored_at
      ]
    end
    array_to_csv(data, [
      _('SCC ID'),
      _('Product'),
      _('Description'),
      _('Mandatory?'),
      _('Mirror?'),
      _('Last mirrored')
    ])
  end

  def to_table
    data = @repositories.map do |repo|
      [
        repo.scc_id,
        repo.description,
        repo.enabled ? _('Mandatory') : _('Not Mandatory'),
        repo.mirroring_enabled ? _('Mirror') : _("Don't Mirror"),
        repo.last_mirrored_at
      ]
    end
    array_to_table(data, [
      _('SCC ID'),
      _('Product'),
      _('Mandatory?'),
      _('Mirror?'),
      _('Last mirrored')
    ])
  end

  def to_tty
    # disabled due to the rare bug in rubocop up to 0.59.1
    # https://github.com/department-of-veterans-affairs/caseflow/issues/8488
    # rubocop:disable Style/FormatStringToken
    data = @repositories.map do |repo|
      [
        repo.name,
        repo.scc_id,
        repo.enabled ? _('mandatory') : _('non-mandatory'),
        repo.mirroring_enabled ? _('enabled') : _('not enabled'),
        repo.last_mirrored_at.present? ? _('mirrored at %{time}') % { time: repo.last_mirrored_at.strftime('%Y-%m-%d %H:%M:%S %Z') } : _('not mirrored')
      ]
    end
    data.each do |entry|
      template = _('* %{name} (id: %{id}) (%{mandatory}, %{enabled}, %{mirrored_at})')
      template_data = { name: entry[0], id: entry[1], mandatory: entry[2], enabled: entry[3], mirrored_at: entry[4] }
      puts template % template_data
    end
    # rubocop:enable Style/FormatStringToken
  end

end
