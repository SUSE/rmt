class RMT::Logger < ActiveSupport::Logger
  def initialize(dest)
    super(dest)

    # LOG_TO_JOURNALD is set by the systemd timers in order to remove duplicate timestamps in the logs
    if ENV['LOG_TO_JOURNALD'].present?
      self.formatter = proc do |severity, _time, _progname, msg|
       "#{severity}: #{msg}\n"
      end
      self.info "RMT version #{RMT::VERSION}"
    else
      self.formatter = ::Logger::Formatter.new
    end
  end
end
