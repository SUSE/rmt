class RMT::CLI::Sync < RMT::CLI::Subcommand
  default_task :scc

  desc 'scc', 'Sync database with SUSE Customer Center', hide: true
  def scc
    abort 'This RMT is in offline-mode. Use `sync airgap` if you want to sync from a portable storage.' if Settings.airgap.offline
    RMT::SCC.new(options).sync
  end

  desc 'airgap', 'Store or read data at Airgap storage for offline usage'
  option :path, desc: 'Overwrite the configured path'
  def airgap
    if Settings.airgap.offline
      RMT::SCC.new(options).import(airgap_path)
    else
      RMT::SCC.new(options).export(airgap_path)
    end
  end

end
