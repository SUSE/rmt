class RMT::CLI::SCC < RMT::CLI::Base

  desc 'sync', 'Synchronize database with SCC'
  def sync
    require 'rmt/config'
    require 'rmt/scc'

    scc = RMT::SCC.new(options)
    scc.sync
  rescue RMT::SCC::CredentialsError, SUSE::Connect::Api::InvalidCredentialsError => e
    raise RMT::CLI::Error, e.to_s
  rescue Interrupt
    raise RMT::CLI::Error, 'Interrupted! You need to rerun this command to have a consistent state.'
  end

end
