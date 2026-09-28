require 'rails_helper'

RSpec.describe Api::Connect::V3::Systems::SystemsController do
  subject(:update_action) { put url, params: payload, headers: headers }

  include_context 'auth header', :system, :login, :password
  include_context 'version header', 3

  # both the request and the deleter need to see committed rows, so this file
  # cannot run inside the transaction RSpec wraps around each example
  self.use_transactional_tests = false

  after do
    SystemProfile.delete_all
    Profile.delete_all
    Activation.delete_all
    System.delete_all
    DeregisteredSystem.delete_all
  end

  let(:system) { FactoryBot.create(:system, hostname: 'initial') }
  let(:url) { '/connect/systems' }
  let(:headers) { auth_header.merge(version_header) }
  let(:hwinfo) do
    {
      cpus: 16,
      sockets: 1,
      arch: 'x86_64',
      hypervisor: 'XEN',
      uuid: 'f46906c5-d87d-4e4c-894b-851e80376003',
      cloud_provider: 'testcloud'
    }
  end
  let(:payload) { { hostname: 'test', hwinfo: hwinfo } }

  # a connection straight from the pool is useless here: it is the very session
  # holding the lock, and a session never blocks on its own row locks
  def second_session
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    Mysql2::Client.new(config.slice(:host, :port, :socket, :username, :password, :database, :encoding).compact)
  end

  # asks the server whether the row is locked *right now* instead of timing a
  # blocking statement. NOWAIT fails immediately with 1205 on MariaDB (3572 on
  # MySQL) when the lock is held and returns the row when it is not, so nothing
  # here depends on timing
  def row_locked?(client)
    client.query("SELECT id FROM systems WHERE id = #{system.id} FOR UPDATE NOWAIT")
    false
  rescue Mysql2::Error => e
    raise unless [1205, 3572].include?(e.error_number)

    true
  end


  describe '#update when the deregistration wins the race' do
    # the deregistration commits after the credentials are checked but before the action takes the row lock
    # the update must be rejected rather than write to a row that is on its way out
    before do
      allow_any_instance_of(described_class).to receive(:authenticate_system).and_wrap_original do |original, *args, **kwargs|
        original.call(*args, **kwargs)

        client = second_session
        begin
          client.query("DELETE FROM systems WHERE id = #{system.id}")
        ensure
          client.close
        end
      end
    end

    it 'rejects the update with 401 instead of writing to the deregistered system' do
      update_action

      expect(response).to have_http_status(:unauthorized)
    end

    it 'leaves the system deregistered' do
      update_action

      expect(System.where(id: system.id)).to be_empty
    end
  end

  describe '#update under concurrent deregistration' do
    def capture_sql
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        statements << payload[:sql]
      end
      yield
      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    # System.lock.find runs just before perform_update, so by the time this
    # wrapper is entered the row lock is held and the transaction is still open.
    # probing from right here needs no second thread, no queue and no sleep (NOWAIT
    # answers immediately, so the action cannot deadlock against itself)
    # a probe on its own thread reports the row unlocked even when it is not, so
    # do not reach for one
    def probe_from_inside_the_action
      # a holder rather than a local, so the example reads the value the wrapper
      # writes when the request runs, not the nil it starts out as
      result = {}

      allow_any_instance_of(described_class).to receive(:perform_update).and_wrap_original do |original, *args|
        client = second_session
        begin
          result[:locked] = row_locked?(client)
        ensure
          client.close
        end

        original.call(*args)
      end
      # rubocop:enable RSpec/AnyInstance

      result
    end

    it 'holds a row lock on the system while the action runs' do
      result = probe_from_inside_the_action
      statements = capture_sql { update_action }

      expect(result[:locked]).not_to be_nil, 'the action never reached perform_update'
      expect(result[:locked]).to be(true), "the row was not locked while the action held its transaction open\nsql=\n  #{statements.join("\n  ")}"
    end
  end
end
