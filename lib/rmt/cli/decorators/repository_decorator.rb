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
    array_to_csv(data)
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

end
