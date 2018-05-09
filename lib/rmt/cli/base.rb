require 'rmt/lockfile'

class RMT::CLI::Base < Thor

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

      shell.say "Run '#{basename} help [COMMAND]' for more information on a command and its subcommands."

      shell.say
      shell.say 'Do you have suggestions for improvement? We would love to hear from you!'
      shell.say 'Check out https://github.com/SUSE/rmt/issues/new'
    end

    def dispatch(command, given_args, given_opts, config)
      handle_exceptions { super(command, given_args, given_opts, config) }
    rescue RMT::CLI::Error => e
      warn e.to_s
      if config[:shell]&.base&.options&.[]('debug')
        warn e.cause ? e.cause.inspect : e.inspect
        warn e.cause ? e.cause.backtrace : e.backtrace
      end
      exit e.exit_code # rubocop:disable Rails/Exit
    end

    def handle_exceptions
      yield
    rescue RMT::Deduplicator::HardlinkException => e
      raise RMT::CLI::Error.new(
        "Could not create deduplication hardlink: #{e.message}.",
        RMT::CLI::Error::ERROR_OTHER
      )
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
    rescue RMT::Lockfile::ExecutionLockedError
      pid = File.read(RMT::Lockfile::LOCKFILE_LOCATION)
      raise RMT::CLI::Error.new(
        "Process is locked by the application with pid #{pid}. Close this application or wait for it to finish before trying again\n",
        RMT::CLI::Error::ERROR_OTHER
      )
    end

    # These methods are needed to properly format the hint outputs for `rmt-cli repos custom`. This is a workaround
    # taken and adapted from https://github.com/erikhuda/thor/issues/261, as Thor does not seem to handle nested subcommands
    # the way we expect it to.
    def banner(command, _namespace = nil, _subcommand = false)
      "#{basename} #{subcommand_prefix} #{command.usage}"
    end

    def subcommand_prefix
      return "\b" if name == RMT::CLI::Main.name
      name.gsub(/.*::/, '').gsub(/^[A-Z]/) { |match| match[0].downcase }.gsub(/[A-Z]/) { |match| " #{match[0].downcase}" }
    end

  end

  private

  def locked_method(&_block)
    RMT::Lockfile.create_file
    begin
      yield
    ensure
      RMT::Lockfile.remove_file
    end
  end

  def needs_path(path)
    File.directory?(path) ? yield : warn("#{path} is not a directory.")
  end

  def mirror!(repo, repository_url: nil, to: RMT::DEFAULT_MIRROR_DIR, to_offline: false)
    repository_url ||= repo.external_url

    puts "Mirroring repository #{repo.name} to #{to}"
    RMT::Mirror.from_url(repo.external_url, repo.auth_token, repository_url: repository_url, base_dir: to, to_offline: to_offline).mirror
    repo.refresh_timestamp!
  rescue RMT::Mirror::Exception => e
    warn e.to_s
  end

end
