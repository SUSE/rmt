class RMT::CLI::Scc < RMT::CLI::Base
  desc 'sync-systems', _('Forward registered systems data to SCC')
  def sync_systems
    RMT::SCC.new(options).sync_systems
  end
end
