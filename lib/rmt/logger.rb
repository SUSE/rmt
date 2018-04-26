class RMT::Logger < ActiveSupport::Logger
  def initialize(dest)
    super(dest)
    self.formatter = if ENV['LOG_TO_JOURNALD'].present?
                       proc do |severity, _time, _progname, msg|
                         "#{severity}: #{msg}\n"
                       end
                     else
                       ::Logger::Formatter.new
                     end
  end
end
