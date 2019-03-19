require 'rails_helper'

RSpec.describe RMT::Lockfile do
  let(:lockfile) { RMT::Lockfile::LOCKFILE_LOCATION }

  describe '#lock', :with_fakefs do
    subject(:lock) { described_class.lock { nil } }

    context 'without file' do
      it 'does not raise exception' do
        expect { lock }.not_to raise_error
      end

      it 'creates a file and locks it' do
        allow(File).to receive(:open).with(lockfile, 66).exactly(1).times.and_call_original
        expect_any_instance_of(File).to receive(:flock).exactly(1).times.and_call_original
        expect_any_instance_of(File).to receive(:truncate).exactly(1).times.and_call_original
        lock
      end
    end

    context 'with locked file' do
      it 'raises exception' do
        expect_any_instance_of(File).to receive(:flock).exactly(1).times.and_return(false)
        expect_any_instance_of(File).to receive(:read).exactly(1).times.and_return('123')
        expect { lock }.to raise_error(
          RMT::Lockfile::ExecutionLockedError,
          "Process is locked by the application with pid 123. Close this application or wait for it to finish before trying again.\n"
        )
      end
    end

    context 'with existing file and log pid' do
      before { File.write(lockfile, 'long_text_but_not_the_process_id') }
      after { File.delete(lockfile) }

      it 'writes proper pid to file' do
        allow(File).to receive(:open).with(lockfile, 66).exactly(1).times.and_call_original
        lock
        expect(File.read(lockfile)).to eq(Process.pid.to_s)
      end
    end
  end
end
