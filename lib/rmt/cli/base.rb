# rubocop:disable Rails/Exit

require 'lockfile'

class RMT::CLI::Base < Thor

  def self.lock(name)
    lock_filename = "#{name}.lock"
    @lockfile = Lockfile.new(lock_filename, retries: 0, max_age: 12 * 60 * 60, refresh: false)
    begin
      @lockfile.lock
    rescue Lockfile::LockError
      raise RMT::CLI::Error.new(
        "Can't obtain a lock on #{lock_filename}",
        RMT::CLI::Error::ERROR_LOCKFILE
      )
    end
  end

  def self.unlock
    return unless @lockfile
    @lockfile.unlock
    @lockfile = nil
  end

  class << self

    # custom output of the help command
    # (removes the alphabetical sorting and adds some custom behavior)
    def help(shell, subcommand = false)
      list = printable_commands(true, subcommand)

      list.reject! { |l| l[0].split.include?('help') }

      shell.say 'Commands:'

      shell.print_table(list, indent: 2, truncate: true)
      shell.say
      class_options_help(shell)

      shell.say "Run '#{basename} COMMAND help [SUBCOMMAND]' for more information on a command."
    end

    def dispatch(command, given_args, given_opts, config)
      handle_exceptions { super(command, given_args, given_opts, config) }
    rescue RMT::CLI::Error => e
      warn e.to_s
      if config[:shell]&.base&.options&.[]('debug')
        warn e.cause ? e.cause.inspect : e.inspect
        warn e.cause ? e.cause.backtrace : e.backtrace
      end
      exit e.exit_code
    end

    def handle_exceptions
      yield
    rescue Mysql2::Error => e
      if e.message =~ /^Access denied/
        raise RMT::CLI::Error.new(
          "Cannot connect to database server. Make sure its credentials are configured in '/etc/rmt.conf'.",
          RMT::CLI::Error::ERROR_DB
        )
      elsif e.message =~ /^Can't connect/
        raise RMT::CLI::Error.new(
          "Cannot connect to database server. Make sure it is running and its credentials are configured in '/etc/rmt.conf'.",
          RMT::CLI::Error::ERROR_DB
        )
      else
        # Unexpected DB error, not handling it
        raise e
      end
    rescue ActiveRecord::NoDatabaseError
      raise RMT::CLI::Error.new(
        "The RMT database has not yet been initialized. Run 'systemctl start rmt-migration' to setup the database.",
        RMT::CLI::Error::ERROR_DB
      )
    rescue RMT::SCC::CredentialsError, ::SUSE::Connect::Api::InvalidCredentialsError
      raise RMT::CLI::Error.new(
        "The SCC credentials are not configured correctly in '/etc/rmt.conf'. You can obtain them from https://scc.suse.com/organization",
        RMT::CLI::Error::ERROR_SCC
      )
    ensure
      begin
        unlock
      rescue Lockfile::LockError => e
        warn e.message if config[:shell]&.base&.options&.[]('debug')
      end
    end

  end

end
