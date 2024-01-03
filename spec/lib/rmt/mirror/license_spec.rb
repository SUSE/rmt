require 'spec_helper'

describe RMT::Mirror::License do
  subject(:license) { described_class.new(**license_configuration) }


  let(:repository) do
    create :repository,
           name: 'HYPE product 15.3',
           external_url: 'https://updates.suse.com/sample/repository/15.3/product/'
  end

  let(:base_dir) { '/test/repository/base/path/' }
  let(:license_configuration) do
    {
      repository: repository,
      logger: RMT::Logger.new('/dev/null'),
      mirroring_base_dir: base_dir
    }
  end

  let(:fixture) { 'directory.yast' }
  let(:config) do
    {
      relative_path: fixture,
      base_dir: file_fixture(''),
      base_url: 'https://updates.suse.de/sles/'
    }
  end
  let(:licenses_ref) { RMT::Mirror::FileReference.new(**config) }

  describe '#licenses_available?' do
    it 'returns true if directory.yast is available'
    it 'returns false if directory.yast is not available'
    it 'does not raise an exception if the directory.yast is not available'
  end

  describe '#mirror_implementation' do
    it 'mirrors all license files'
    it 'creates a temporary directory & syncs the content at the end'
    it 'raises if mirroring failed'
  end
end
