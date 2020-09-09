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
    # We need to remove the Installer-Updates from our list of repos because they are added by default.
    # We cannot just keep them and change the expectation because the number will grow with every newly released product
    # and break this test.
    expect(`/usr/bin/rmt-cli repos list | grep -v Installer-Updates | wc -l`.strip&.to_i).to eq(10) # 5 lines for table headers
  end
end
