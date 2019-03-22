class RMT::Lockfile
  LOCKFILE_LOCATION = '/tmp/rmt.lock'.freeze
  ExecutionLockedError = Class.new(StandardError)

  class << self
    def lock
      # https://ruby-doc.org/core-2.5.0/File.html#method-i-flock
      File.open(RMT::Lockfile::LOCKFILE_LOCATION, File::RDWR | File::CREAT) do |f|
        if f.flock(File::LOCK_EX | File::LOCK_NB)
          f.write(Process.pid.to_s)
          f.flush
          f.truncate(f.pos)
        else
          pid = File.read(RMT::Lockfile::LOCKFILE_LOCATION)
          raise ExecutionLockedError.new(
            _('Process is locked by the application with pid %{pid}. Close this application or wait for it to finish before trying again.') \
                % { pid: pid } + "\n"
          )
        end

        yield
      end
    end
  end
end
