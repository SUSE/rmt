class RMT::CLI::SCC < RMT::CLI::Base

  desc 'sync', 'Synchronize database with SCC'
  option :to_dir, desc: 'Write info to a directory instead of database'
  option :from_dir, desc: 'Read info from a directory instead of SCC'
  def sync
    require 'rmt/config'
    require 'rmt/scc'
    require 'suse/connect/api'
    scc = RMT::SCC.new(options)
    if options[:to_dir]
      scc.sync_to_dir(sync_dir: options[:to_dir])
    elsif options[:from_dir]
      scc.sync_from_dir(sync_dir: options[:from_dir])
    else
      scc.sync
    end
  rescue Interrupt
    raise RMT::CLI::Error, 'Interrupted! You need to rerun this command to have a consistent state.'
  end

end
