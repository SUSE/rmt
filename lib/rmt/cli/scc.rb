class RMT::CLI::SCC < RMT::CLI::Base
  desc 'sync', 'Get latest data from SCC'
  def sync
    RMT::SCC.new(options).sync
  end

  desc 'export PATH', 'Store data from SCC in PATH'
  def export(path)
    RMT::SCC.new(options).export(path)
  end

  desc 'import PATH', 'Read data from PATH instead of SCC'
  def import(path)
    RMT::SCC.new(options).import(path)
  end
end
