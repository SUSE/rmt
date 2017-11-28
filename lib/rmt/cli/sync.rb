class RMT::CLI::Sync < RMT::CLI::Subcommand
  default_task :scc

  desc 'scc', 'Sync database with SUSE Customer Center', hide: true
  def scc
    abort 'This RMT is in offline-mode. Use `sync airgap` if you want to sync from a portable storage.' if Settings.airgap.offline
    RMT::SCC.new(options).sync
  end

end
