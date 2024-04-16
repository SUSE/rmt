require File.expand_path('../support/command_rspec_helper', __FILE__)

describe 'rmt data importer' do
  describe 'import repo from smt' do
    let(:fixtures) { File.expand_path('../spec/fixtures/files/dummy_export/', File.dirname(__FILE__)) }

    before do
      command "/usr/bin/rmt-data-import --no-systems --no-hwinfo -d #{fixtures}"
    end
    after do
      `/usr/bin/rmt-cli repos disable 3114`
    end
    it do
      expect(`/usr/bin/rmt-cli repos list`).to include('3114', '| Mirror')
    end
  end
end
