require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'mirror' do
  command '/usr/bin/rmt-cli mirror'
  its(:exitstatus) { is_expected.to eq 0 }
end
