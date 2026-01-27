require 'mixlib/shellout'

describe 'rmt-cli' do
  describe 'lockfile' do

    around do |example|
      parent_pid = spawn('/usr/bin/rmt-cli sync > /dev/null')
      example.run
      # wait for the parent process to finish, so the lock is released
      Process.waitpid(parent_pid)
    end

    it do
      command = Mixlib::ShellOut.new("/usr/bin/rmt-cli sync")
      command.run_command

      expect(command.stderr).to match(/already running. Terminate the other instance/)
      expect(command.exitstatus).to eq(1)
    end
  end
end
