require 'open3'

describe 'rmt-cli' do
  describe 'lockfile' do

    around do |example|
      parent_pid = fork do
        system "/usr/bin/rmt-cli sync > /dev/null"
      end
      # Give the forked process time to start and acquire the lock
      sleep 1
      example.run
      # wait for the parent process to finish, so the lock is released
      Process.wait(parent_pid)
    end

    it do
      _stdout, stderr, status = Open3.capture3('/usr/bin/rmt-cli sync')

      expect(stderr).to match(/already running. Terminate the other instance/)
      expect(status.exitstatus).to eq(1)
    end
  end
end
