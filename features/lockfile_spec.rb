require File.expand_path('../support/command_rspec_helper', __FILE__)
require 'thread'
require 'active_record'
require_relative '../lib/rmt/config'
require_relative '../lib/rmt/lockfile'

describe 'rmt-cli' do
  describe 'lockfile' do

    before(:context) do
      ActiveRecord::Base.establish_connection(RMT::Config.db_config)
      adapter_name = ActiveRecord::Base.connection.adapter_name
      skip 'Lockfile CLI spec requires MySQL backend' unless adapter_name == 'Mysql2'
    rescue StandardError => e
      skip "Unable to establish database connection for lockfile spec: #{e.message}"
    end

    around do |example|
      lock_ready = Queue.new
      release_gate = Queue.new

      locker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          RMT::Lockfile.lock do
            lock_ready << :locked
            release_gate.pop
          end
        end
      rescue StandardError => e
        lock_ready << e
      end

      lock_signal = lock_ready.pop
      raise lock_signal if lock_signal.is_a?(Exception)

      example.run
    ensure
      release_gate << :release if defined?(release_gate)
      locker.join if defined?(locker) && locker
    end

    command '/usr/bin/rmt-cli sync', allow_error: true
    its(:stderr) do
      is_expected.to eq(
        "Another instance of this command is already running. Terminate" \
        " the other instance or wait for it to finish.\n"
      )
    end

    its(:exitstatus) { is_expected.to eq 1 }
  end
end
