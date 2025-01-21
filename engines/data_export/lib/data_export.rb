$LOAD_PATH.push File.expand_path(__dir__, '..')

module DataExport
  class << self
    # rubocop:disable ThreadSafety/ClassAndModuleAttributes
    attr_accessor :handler
    # rubocop:enable ThreadSafety/ClassAndModuleAttributes
  end

  class Exception < RuntimeError; end
end

module DataExport::Handlers
end

require 'data_export/engine'
require 'data_export/handler_base'

handlers = Dir.glob(File.join(__dir__, 'data_export/handlers/*.rb'))

raise 'Too many data export handlers found' if handlers.size > 1

# rubocop:disable Lint:UnreachableLoop
handlers.each do |f|
  require_relative f
  break
end
# rubocop:enable Lint:UnreachableLoop
