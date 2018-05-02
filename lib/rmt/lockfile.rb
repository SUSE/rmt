class RMT::Lockfile
  LOCKFILE_LOCATION = File.expand_path('../../tmp/pids/rmt.pid', __dir__).freeze

  class << self
    def create_file
      if File.exist?(LOCKFILE_LOCATION)
        raise RMT::ExecutionLockedError
      else
        dirname = File.dirname(LOCKFILE_LOCATION)
        FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
        File.open(LOCKFILE_LOCATION, 'w') { |f| f.write(Process.pid) }
        true
      end
    end

    def remove_file
      File.delete(LOCKFILE_LOCATION) if File.exist?(LOCKFILE_LOCATION)

      true
    end
  end
end
