require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'mirror' do
  before { system '/usr/bin/rmt-cli repos enable 3114' }

  command '/usr/bin/rmt-cli mirror'
  its(:exitstatus) { is_expected.to eq 0 }
end
