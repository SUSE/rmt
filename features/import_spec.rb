require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'rmt data importer' do
  describe 'import repo from smt' do
    before do
      command '/usr/bin/rmt-data-import --no-systems --no-hwinfo -d /tmp/rmt-server/spec/fixtures/files/dummy_export'
    end
    after do
      `/usr/bin/rmt-cli repos disable 3114`
    end
    it do
      expect(`/usr/bin/rmt-cli repos list`).to include('3114', '| Mirror')
    end
  end
end
