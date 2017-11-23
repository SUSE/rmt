class RMT::CLI::SCC < RMT::CLI::Subcommand

  desc 'sync', 'Get latest SCC data'
  def sync
    if Settings.air_gap.offline
      RMT::SCC.new(options).import(airgap_path)
    else
      RMT::SCC.new(options).sync
    end
  end

  desc 'export', 'Store SCC data for offline usage'
  option :path, desc: 'Overwrite the configured path'
  def export
    abort 'This RMT is in offline-mode and cannot export SCC data.' if Settings.air_gap.offline
    RMT::SCC.new(options).export(airgap_path)
  end

end
