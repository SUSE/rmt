require 'rails_helper'

RSpec.describe RMT::Lockfile do
  let(:lockfile) { RMT::Lockfile::LOCKFILE_LOCATION }

  describe '#lock' do
    subject(:lock) { described_class.lock { nil } }

    context 'without file' do
      it 'does not raise exception' do
        FakeFS.with_fresh do
          expect { lock }.not_to raise_error
        end
      end

      it 'creates a file and locks it' do
        FakeFS.with_fresh do
          allow(File).to receive(:open).with(lockfile, 66).exactly(1).times.and_call_original
          expect_any_instance_of(File).to receive(:flock).exactly(3).times.and_call_original
          lock
        end
      end
    end

    context 'with locked file' do
      it 'raises exception' do
        FakeFS.with_fresh do
          expect_any_instance_of(File).to receive(:flock).exactly(1).times.and_return(false)
          expect { lock }.to raise_error(RMT::Lockfile::ExecutionLockedError)
        end
      end
    end
  end
end
