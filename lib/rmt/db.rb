# frozen_string_literal: true

# :nocov: (only used in docker-compose setup)

module RMT
  # The DB module has useful methods for DB purposes. This is largely based on
  # SUSE/Portus.
  module Db
    WAIT_TIMEOUT  = 90
    WAIT_INTERVAL = 5

    # Pings the DB and returns a proper symbol depending on the situation:
    #   * ready: the database has been created and initialized.
    #   * empty: the database has been created but has not been initialized.
    #   * missing: the database has not been created.
    #   * down: cannot connect to the database.
    #   * unknown: there has been an unexpected error.
    def self.ping
      ::RMT::Db.migrations? ? :ready : :empty
    rescue ActiveRecord::NoDatabaseError
      :missing
    rescue Mysql2::Error
      :down
    rescue StandardError
      :unknown
    end

    # Returns true if the migrations have been run. The implementation is pretty
    # trivial, but this gives us a nice way to test this module.
    def self.migrations?
      ActiveRecord::Base.connection
      return unless ActiveRecord::Base.connection.table_exists? 'schema_migrations'

      !ActiveRecord::Base.connection.migration_context.needs_migration?
    end

    def self.setup!
      count = 0

      loop do
        case ::RMT::Db.ping
        when :down
          Rails.logger.info 'Database not ready yet. Waiting...'
          sleep WAIT_INTERVAL
          count += 5
        when :empty
          Rails.logger.info 'Database empty: migrating...'
          system('bundle exec rake db:migrate')
        when :missing
          Rails.logger.info 'Database missing: creating...'
          system('bundle exec rake db:create')
        when :ready
          Rails.logger.info 'Database ready!'
          break
        end

        raise ::RMT::Db::TimeoutReachedError if count >= WAIT_TIMEOUT
      end
    end

    # Raised if any timeout reached
    class TimeoutReachedError < RuntimeError; end
  end
end
# :nocov:
