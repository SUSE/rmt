require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'rmt-cli' do
  before { `/usr/bin/rmt-cli sync > /dev/null &` }
  # kill running process to let further specs pass
  after { `kill -9 $(cat /tmp/rmt.lock)` }

  describe 'lockfile' do
    command '/usr/bin/rmt-cli sync', allow_error: true

    its(:stderr) { is_expected.to eq("Process is locked by the application with \
pid #{File.read('/tmp/rmt.lock')}. Close this application or wait for it \
to finish before trying again\n") }

    its(:exitstatus) { is_expected.to eq 1 }
  end
end
