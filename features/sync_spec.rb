require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'rmt-cli' do
  describe 'sync' do
    command '/usr/bin/rmt-cli sync'
    its(:exitstatus) { is_expected.to eq 0 }

    it do
      expect(`/usr/bin/rmt-cli products list --all | wc -l`.strip&.to_i ).to be >= 361
      expect(`/usr/bin/rmt-cli repos list --all | wc -l`.strip&.to_i ).to be >= 839
    end
  end
end
