require 'rails_helper'

RSpec.describe RMT::Lockfile do
  let(:lockfile) { RMT::Lockfile::LOCKFILE_LOCATION }

  describe '#create_file' do
    subject(:create_file) { described_class.create_file }

    context 'without file' do
      it 'does not raise exception' do
        FakeFS.with_fresh do
          expect { create_file }.not_to raise_error
        end
      end

      it 'creates a file' do
        FakeFS.with_fresh do
          allow(File).to receive(:open).with(lockfile, 'w').exactly(1).times.and_return(true)
          create_file
        end
      end
    end

    context 'with existing file' do
      it 'raises exception' do
        FakeFS.with_fresh do
          described_class.create_file
          expect { create_file }.to raise_error(RMT::Lockfile::ExecutionLockedError)
        end
      end
    end
  end

  describe '#remove_file' do
    subject(:remove_file) { described_class.remove_file }

    context 'without file' do
      it 'returns true' do
        FakeFS.with_fresh do
          expect { remove_file }.not_to raise_error
        end
      end
    end

    context 'with existing file' do
      it 'does not raise exception' do
        FakeFS.with_fresh do
          described_class.create_file
          expect { remove_file }.not_to raise_error
        end
      end

      it 'removes file' do
        FakeFS.with_fresh do
          described_class.create_file
          expect(File).to receive(:delete).with(lockfile).exactly(1).times.and_return(true)
          remove_file
        end
      end
    end
  end
end
