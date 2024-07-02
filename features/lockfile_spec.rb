describe 'rmt-cli lock' do
  around do |example|
    parent_pid = fork do
      exec "/usr/bin/rmt-cli sync > /dev/null"
    end
    example.run
    Process.kill('KILL', parent_pid)
  end

  describe 'lockfile' do
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
