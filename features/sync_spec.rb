require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'rmt-cli' do
  describe 'sync' do
    command '/usr/bin/rmt-cli sync'
    its(:exitstatus) { is_expected.to eq 0 }
    its(:stdout) { is_expected.to include("INFO -- : Cleaning up the database\n") }
    its(:stdout) { is_expected.to include("INFO -- : Downloading data from SCC\n") }
    its(:stdout) { is_expected.to include("INFO -- : Updating products\n") }
    its(:stdout) { is_expected.to include("INFO -- : Updating repositories\n") }
    its(:stdout) { is_expected.to include("INFO -- : Updating subscriptions\n") }
  end
end
