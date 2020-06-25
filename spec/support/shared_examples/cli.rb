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
    before do
      allow(RMT::Lockfile).to receive(:obtain_lock).and_return(false)
    end

    it 'handles lockfile exception' do
      expect(described_class).to receive(:exit)
      expect { command }.to output(
        "Another instance of this command is already running. Terminate the other instance or wait for it to finish.\n"
      ).to_stderr
    end
  end
end
