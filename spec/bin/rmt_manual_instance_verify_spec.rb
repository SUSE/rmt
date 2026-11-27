require 'rails_helper'
require 'open3'

describe 'bin/rmt-manual-instance-verify' do # rubocop:disable RSpec/DescribeClass
  # The script must set up bundler itself. Run it without the bundler
  # environment of rspec and without rubygems, so globally installed
  # gems cannot hide a missing `bundler/setup`.
  it 'loads its dependencies and asks for missing parameters' do
    script = Rails.root.join('bin/rmt-manual-instance-verify').to_s
    stdout, stderr, status = Bundler.with_unbundled_env do
      Open3.capture3(RbConfig.ruby, '--disable-gems', script)
    end

    expect(stderr).to be_empty
    expect(stdout).to eq("Missing either --instance-data or --client-ip parameter\n")
    expect(status.exitstatus).to eq(1)
  end
end
