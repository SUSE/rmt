class RMT::CLI::SCC < RMT::CLI::Base

  desc 'sync', 'Synchronize database with SCC'
  def sync
    require 'rmt/config'
    require 'rmt/scc'
    require 'suse/connect/api'

    scc = RMT::SCC.new(options)
    scc.sync
  rescue Interrupt
    raise RMT::CLI::Error, 'Interrupted! You need to rerun this command to have a consistent state.'
  end

end
