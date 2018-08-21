require File.expand_path('../support/command_rspec_helper', __FILE__)


describe 'enable repos' do
  let(:repos) { [3114, 3115, 3116, 2705, 2707] }

  before do
    repos.each do |repo_id|
      `/usr/bin/rmt-cli repos enable #{repo_id}`
    end
  end

  after do
    repos.each do |repo_id|
      `/usr/bin/rmt-cli repos disable #{repo_id}`
    end
  end

  it do
    expect(`/usr/bin/rmt-cli repos list --csv | wc -l`.strip&.to_i ).to eq(5)
  end
end
