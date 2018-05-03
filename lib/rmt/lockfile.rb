class RMT::Lockfile
  LOCKFILE_LOCATION = File.expand_path('../../tmp/rmt.lock', __dir__).freeze
  ExecutionLockedError = Class.new(StandardError)

  class << self
    def create_file
      if File.exist?(LOCKFILE_LOCATION)
        raise RMT::Lockfile::ExecutionLockedError
      else
        dirname = File.dirname(LOCKFILE_LOCATION)
        FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
        File.open(LOCKFILE_LOCATION, 'w') { |f| f.write(Process.pid) }
      end
    end

    def remove_file
      File.delete(LOCKFILE_LOCATION) if File.exist?(LOCKFILE_LOCATION)
    end
  end
end
