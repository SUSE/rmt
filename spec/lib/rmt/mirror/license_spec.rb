require 'rails_helper'

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
      logger: logger,
      mirroring_base_dir: base_dir
    }
  end

  let(:logger) { RMT::Logger.new('/dev/null') }

  let(:fixture) { 'directory.yast' }
  let(:license_listing_configuration) do
    {
      relative_path: fixture,
      base_dir: file_fixture(''),
      base_url: 'https://updates.suse.de/sles/'
    }
  end
  let(:licenses_ref) { RMT::Mirror::FileReference.new(**license_listing_configuration) }

  before do
    allow(FileUtils).to receive(:mkpath).with(license.repository_path).and_return(nil)
    described_class.send(:public, *described_class.protected_instance_methods)
  end

  describe '#licenses_available?' do
    it 'returns true if directory.yast is available' do
      stub_request(:head, license.repository_url('directory.yast')).to_return(status: 200, body: '', headers: {})
      expect(license.licenses_available?).to eq(true)
    end

    it 'returns false if directory.yast is not available' do
      stub_request(:head, license.repository_url('directory.yast')).to_return(status: 404, body: '', headers: {})
      expect(logger).to receive(:debug)
      expect(license.licenses_available?).to eq(false)
    end

    it 'does not raise an exception if the directory.yast is not available' do
      stub_request(:head, license.repository_url('directory.yast')).to_return(status: 404, body: '', headers: {})
      expect { license.licenses_available? }.not_to raise_error
    end
  end

  describe '#mirror_implementation' do
    before do
      allow(license).to receive(:create_temp_dir).with(:license).and_return('/tmp/foo')
    end

    let(:downloader) { instance_double 'RMT::Downloader' }

    it 'mirrors all license files' do
      allow(license).to receive(:licenses_available?).and_return(true)
      allow(license).to receive(:temp).with(:license).at_least(13).times.and_return('/tmp/foo')
      allow(license).to receive(:download_cached!).with('directory.yast', to: '/tmp/foo').and_return(licenses_ref)
      expect(license).to receive(:download_enqueued)
      expect(license).to receive(:enqueue).with(duck_type(:local_path)).exactly(11).times
      expect(license).to receive(:move_files).with(glob: File.join(license.temp(:license), '*'), destination: license.repository_path)

      license.mirror_implementation
    end

    it 'raises if mirroring failed' do
      allow(license).to receive(:licenses_available?).and_return(true)
      allow(license).to receive(:downloader).and_return(downloader)
      allow(license).to receive(:temp).with(:license).at_least(12).times.and_return('/tmp/foo')
      allow(license).to receive(:download_cached!).with('directory.yast', to: '/tmp/foo').and_return(licenses_ref)
      expect(license).to receive(:enqueue).with(duck_type(:local_path)).exactly(11)
      expect(downloader).to receive(:download_multi).and_raise(RMT::Downloader::Exception, 'foo bar')

      expect { license.mirror_implementation }.to raise_error(RMT::Mirror::Exception, //)
    end
  end
end
