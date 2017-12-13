require 'rails_helper'

RSpec.describe RMT::Lockfile do
  let(:lockfile) { RMT::Lockfile::LOCKFILE_LOCATION }

  describe '#create_file' do
    subject(:create_file) { described_class.create_file }

    context 'without file' do
      before do
        allow(File).to receive(:exist?).with(lockfile).and_return(false)
        allow(Process).to receive(:pid).and_return(42)
      end

      it 'returns true' do
        expect(create_file).to be true
      end

      it 'creates a file' do
        allow(File).to receive(:open).with(lockfile, 'w').exactly(1).times.and_return(true)
        create_file
      end
    end

    context 'with existing file' do
      before do
        allow(File).to receive(:exist?).with(lockfile).and_return(true)
      end

      it 'raises exception' do
        expect { create_file }.to raise_error(RMT::ExecutionLockedError)
      end
    end
  end

  describe '#remove_file' do
    subject(:remove_file) { described_class.remove_file }

    context 'without file' do
      before do
        allow(File).to receive(:exist?).with(lockfile).and_return(false)
      end

      it 'returns true' do
        expect(remove_file).to be true
      end
    end

    context 'with existing file' do
      before do
        allow(File).to receive(:exist?).with(lockfile).and_return(true)
      end

      it 'returns true' do
        expect(remove_file).to be true
      end

      it 'removes file' do
        expect(File).to receive(:delete).with(lockfile).exactly(1).times.and_return(true)
        remove_file
      end
    end
  end
end
