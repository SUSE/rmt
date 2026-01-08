describe 'rmt-cli' do
  describe 'lockfile' do

    around do |example|
      parent_pid = fork do
        exec "/usr/bin/rmt-cli sync > /dev/null"
      end
      example.run
      # wait for the parent process to finish, so the lock is released
      Process.waitpid(parent_pid)
    end

    it 'sucks' do
      expect { system '/usr/bin/rmt-cli sync' }.to output("Another instance of this command is already running. Terminate the other instance or wait for it to finish.").to_stdout
    end

    # its(:exitstatus) { is_expected.to eq 1 }
  end
end
