module RMT::CLI::RepoPrintable

  def repositories_to_table(repositories)
    rows = []
    repositories.all.each do |repository|
      rows << [
        repository.id,
        repository.name,
        repository.description,
        repository.enabled,
        repository.mirroring_enabled,
        repository.last_mirrored_at
      ]
    end
    Terminal::Table.new headings: ['ID', 'Name', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored'], rows: rows
  end

end
