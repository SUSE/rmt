require 'open3'

describe 'rmt-cli' do
  describe 'sync' do
    it do
      _stdout, _stderr, status = Open3.capture3('/usr/bin/rmt-cli sync')
      expect(status.exitstatus).to eq(0)
    end

    it do
      expect(`/usr/bin/rmt-cli products list --all | wc -l`.strip&.to_i ).to be >= 361
      expect(`/usr/bin/rmt-cli repos list --all | wc -l`.strip&.to_i ).to be >= 839
    end
  end
end
