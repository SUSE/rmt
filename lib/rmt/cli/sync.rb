class RMT::CLI::Sync < RMT::CLI::Subcommand
  default_task :scc

  desc 'scc', 'Sync database with SUSE Customer Center', hide: true
  def scc
    if Settings.airgap.offline
      RMT::SCC.new(options).import(airgap_path)
    else
      RMT::SCC.new(options).sync
    end
  end

  desc 'airgap', 'Store data on Airgap storage for offline usage'
  option :path, desc: 'Overwrite the configured path' # TODO
  def airgap
    abort 'This RMT is in offline-mode and cannot export SCC data.' if Settings.airgap.offline
    RMT::SCC.new(options).export(airgap_path)
  end

end
