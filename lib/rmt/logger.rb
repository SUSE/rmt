class RMT::Logger < ActiveSupport::Logger

  # For syslog log levels, see: man syslog(2)
  # For Ruby log levels, see: https://github.com/ruby/ruby/blob/trunk/lib/logger.rb
  RUBY_TO_SYSLOG_MAPPING = {
    ::Logger::DEBUG   => 7,
    ::Logger::INFO    => 6,
    ::Logger::WARN    => 4,
    ::Logger::ERROR   => 3,
    ::Logger::FATAL   => 2,
    ::Logger::UNKNOWN => 6
  }.freeze

  LABEL_TO_SEVERITY_MAPPING = {
    'DEBUG'   => ::Logger::DEBUG,
    'INFO'    => ::Logger::INFO,
    'WARN'    => ::Logger::WARN,
    'ERROR'   => ::Logger::ERROR,
    'FATAL'   => ::Logger::FATAL,
    'ANY'     => ::Logger::UNKNOWN
  }.freeze

  def initialize(dest)
    super(dest)

    # LOG_TO_JOURNALD is set by the systemd timers in order to remove duplicate timestamps in the logs
    if ENV['LOG_TO_JOURNALD'].present?
      self.formatter = proc do |severity, _time, _progname, msg|
        syslog_severity = RUBY_TO_SYSLOG_MAPPING[LABEL_TO_SEVERITY_MAPPING[severity]]
        "<#{syslog_severity}>#{severity}: #{msg}\n"
      end
      info "RMT version #{RMT::VERSION}"
    else
      self.formatter = ::Logger::Formatter.new
    end
  end
end
