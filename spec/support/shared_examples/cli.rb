shared_examples 'handles non-existing path' do
  context 'with non-existing path' do
    it 'complains and exits' do
      expect { command }.to raise_error(SystemExit).and(output("#{path} is not a directory.\n").to_stderr)
    end
  end
end

shared_examples 'handles non-writable path' do
  context 'with path without write permissions for user' do
    it 'complains and exits' do
      expect(File).to receive(:directory?).and_return(true)
      expect(File).to receive(:writable?).and_return(false)
      expect { command }.to raise_error(SystemExit).and(output("#{path} is not writable by user #{RMT::CLI::Base.process_user_name}.\n").to_stderr)
    end
  end
end

shared_examples 'handles lockfile exception' do
  context 'with existing lockfile' do
    let(:pid) { 42 }

    before do
      allow_any_instance_of(FakeFS::File).to receive(:flock).and_return(false)
      allow(FakeFS::File).to receive(:read).with(::RMT::Lockfile::LOCKFILE_LOCATION).and_return(pid)
    end

    it 'handles lockfile exception' do
      expect(described_class).to receive(:exit)
      expect { command }.to output(
        "Process is locked by the application with pid #{pid}. Close this application or wait for it to finish before trying again.\n"
      ).to_stderr
    end
  end
end
