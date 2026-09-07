class RMT::Lockfile
  ExecutionLockedError = Class.new(StandardError)

  # an interactive command should report that the lock is taken rather than sit
  # there silently, so the default is to give up almost at once
  # Batch jobs pass a longer wait to queue behind whatever is running
  DEFAULT_TIMEOUT = 1

  class << self
    def lock(lock_name = nil, timeout: DEFAULT_TIMEOUT)
      if ActiveRecord::Base.connection.adapter_name != 'Mysql2'
        yield
        return
      end

      lock_name = ['rmt-cli', lock_name].compact.join('-')

      is_lock_obtained = obtain_lock(lock_name, timeout)
      unless is_lock_obtained
        raise ExecutionLockedError.new(
          _('Another instance of this command is already running. Terminate the other instance or wait for it to finish.')
        )
      end

      begin
        yield
      ensure
        # released here rather than after the block: an exception escaping the
        # command would otherwise leave the lock held for the rest of the session
        release_lock(lock_name)
      end
    end

    protected

    def obtain_lock(lock_name, timeout = DEFAULT_TIMEOUT)
      quoted_lock_name = ActiveRecord::Base.connection.quote(lock_name)
      # get_lock returns 1 if lock was obtained, 0 otherwise
      result = ActiveRecord::Base.connection.execute("SELECT GET_LOCK(#{quoted_lock_name}, #{timeout.to_i})")
      result.first.first == 1
    end

    def release_lock(lock_name)
      quoted_lock_name = ActiveRecord::Base.connection.quote(lock_name)
      ActiveRecord::Base.connection.execute("SELECT RELEASE_LOCK(#{quoted_lock_name})")
    end
  end
end
