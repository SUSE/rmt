require File.expand_path('../support/command_rspec_helper', __FILE__)

[3114, 3115, 3116, 2705, 2707].each do |repo_id|
  describe 'enable repos' do
    command "/usr/bin/rmt-cli repos enable #{repo_id}"
    its(:stdout) { is_expected.to eq("Repository successfully enabled.\n") }
  end
end
