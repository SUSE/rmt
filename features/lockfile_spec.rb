require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'rmt-cli' do
  describe 'lockfile' do

    around do |example|
      parent_pid = fork do
        exec "/usr/bin/rmt-cli sync > /dev/null"
      end
      example.run
      Process.kill('INT', parent_pid)
    end

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
