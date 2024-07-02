describe 'rmt-cli' do
  around do |example|
    parent_pidfile = "/tmp/rmt-parent-#{Process.pid}.pid"

    File.write('/tmp/rmt.lock', 'long_text_but_not_the_process_id')
    `chown _rmt /tmp/rmt.lock`

    fork {
      File.write(parent_pidfile, Process.pid)
      exec "/usr/bin/rmt-cli sync > /dev/null"
    }
    example.run
    Process.kill('TERM', File.read(parent_pidfile).to_i)
    FileUtils.rm('/tmp/rmt.lock', force: true)
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
