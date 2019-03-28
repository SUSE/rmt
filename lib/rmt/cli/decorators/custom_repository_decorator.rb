class RMT::CLI::Decorators::CustomRepositoryDecorator < RMT::CLI::Decorators::Base

  def initialize(repositories)
    @repositories = repositories
  end

  def to_csv
    data = @repositories.map do |repo|
      [
        repo.id,
        repo.name,
        repo.external_url,
        repo.enabled,
        repo.mirroring_enabled,
        repo.last_mirrored_at
      ]
    end
    array_to_csv(data, [
      _('ID'),
      _('Name'),
      _('URL'),
      _('Mandatory?'),
      _('Mirror?'),
      _('Last Mirrored')
    ])
  end

  def to_table
    data = @repositories.map do |repo|
      [
        repo.id,
        repo.name,
        repo.external_url,
        repo.enabled ? _('Mandatory') : _('Not Mandatory'),
        repo.mirroring_enabled ? _('Mirror') : _("Don't Mirror"),
        repo.last_mirrored_at
      ]
    end
    array_to_table(data, [
      _('ID'),
      _('Name'),
      _('URL'),
      _('Mandatory?'),
      _('Mirror?'),
      _('Last Mirrored')
    ])
  end

end
