require 'rmt/mirror'
require 'rmt/scc'

module RMT
  module CLI
    class Error < RuntimeError

      ERROR_OTHER = 1
      ERROR_DB = 2
      ERROR_SCC = 3

      attr_accessor :exit_code
      def initialize(msg, exit_code = ERROR_OTHER)
        @exit_code = exit_code
        super(msg)
      end

    end
  end
end
