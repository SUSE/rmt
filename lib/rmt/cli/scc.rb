class RMT::CLI::SCC < RMT::CLI::Base

  desc 'sync', 'Synchronize database with SCC'
  def sync
    require 'rmt/config'
    require 'rmt/scc'

    scc = RMT::SCC.new(options)
    scc.sync
  end

end
