require 'mixlib/shellout'

describe 'rmt-cli' do
  describe 'sync' do
    it do
      command = Mixlib::ShellOut.new("/usr/bin/rmt-cli sync").run_command
      expect(command.exitstatus).to eq(0)
    end

    it do
      expect(`/usr/bin/rmt-cli products list --all | wc -l`.strip&.to_i ).to be >= 361
      expect(`/usr/bin/rmt-cli repos list --all | wc -l`.strip&.to_i ).to be >= 839
    end
  end
end
