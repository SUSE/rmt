require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'rmt-cli' do
  before do
    `echo long_text_but_not_the_process_id > /tmp/rmt.lock`
    `chown _rmt /tmp/rmt.lock`
    `/usr/bin/rmt-cli sync > /dev/null &`
  end
  # kill running process to let further specs pass
  after { `pkill -9 -f rmt-cli` }

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
