require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'rmt-cli' do
  before do
    `echo long_text_but_not_the_process_id > /tmp/rmt.lock`
    `chown _rmt /tmp/rmt.lock`
    `/usr/bin/rmt-cli sync > /dev/null &`
  end
  # kill running process to let further specs pass
  after { `kill -9 $(cat /tmp/rmt.lock)` }

  describe 'lockfile' do
    command '/usr/bin/rmt-cli sync', allow_error: true
    its(:stderr) { is_expected.to eq("Process is locked by the application with \
pid #{`pgrep rmt-cli`.strip}. Close this application or wait for it __I_WANT_IT_FAILING__ \
to finish before trying again.\n") }

    its(:exitstatus) { is_expected.to eq 1 }
  end
end
