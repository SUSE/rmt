require 'rails_helper'

RSpec.describe RMT::Lockfile do
  let(:lock_name) { nil }

  describe '#lock' do
    subject(:lock) { described_class.lock(lock_name) { nil } }

    context 'with an unnamed lock' do
      context 'without a lock' do
        it 'does not raise exception' do
          expect { lock }.not_to raise_error
        end

        it 'obtains a lock' do
          expect(described_class).to receive(:obtain_lock).exactly(1).times.and_call_original
          expect_any_instance_of(ActiveRecord::ConnectionAdapters::Mysql2Adapter).to receive(:execute)
              .exactly(1).with("SELECT GET_LOCK('rmt-cli', 1)").times.and_call_original
          expect_any_instance_of(ActiveRecord::ConnectionAdapters::Mysql2Adapter).to receive(:execute)
              .exactly(1).with("SELECT RELEASE_LOCK('rmt-cli')").times.and_call_original
          lock
        end
      end
    end

    context 'with a named lock' do
      let(:lock_name) { 'test' }

      context 'without a lock' do
        it 'does not raise exception' do
          expect { lock }.not_to raise_error
        end

        it 'obtains a lock' do
          expect(described_class).to receive(:obtain_lock).exactly(1).times.and_call_original
          expect_any_instance_of(ActiveRecord::ConnectionAdapters::Mysql2Adapter).to receive(:execute)
              .exactly(1).with("SELECT GET_LOCK('rmt-cli-test', 1)").times.and_call_original
          expect_any_instance_of(ActiveRecord::ConnectionAdapters::Mysql2Adapter).to receive(:execute)
              .exactly(1).with("SELECT RELEASE_LOCK('rmt-cli-test')").times.and_call_original
          lock
        end
      end
    end

    context 'with locked file' do
      it 'raises exception' do
        expect(described_class).to receive(:obtain_lock).exactly(1).times.and_return(false)
        expect { lock }.to raise_error(
          RMT::Lockfile::ExecutionLockedError,
          'Another instance of this command is already running. Terminate the other instance or wait for it to finish.'
        )
      end
    end
  end
end
