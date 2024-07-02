describe 'rmt-cli' do
  around do |example|
    parent_pidfile = "/tmp/rmt-parent-#{Process.pid}.pid"

    `echo long_text_but_not_the_process_id > /tmp/rmt.lock`
    `chown _rmt /tmp/rmt.lock`

    fork {
      File.write(parent_pidfile, Process.pid)
      exec "/usr/bin/rmt-cli sync >/dev/null"
    }
    example.run
    Process.kill('TERM', File.read(parent_pidfile).to_i)
    File.delete('/tmp/rmt.lock')
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
