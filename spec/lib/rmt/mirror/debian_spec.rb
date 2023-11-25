require 'rails_helper'

RSpec.describe RMT::Mirror::Debian do
  let(:debian) { described_class.new(**configuration) }

  let(:configuration) do
    {
      logger: logger,
      base_dir: base_dir,
      repo: repository,
      mirror_sources: false,
      airgapped: false
    }
  end

  let(:logger) { RMT::Logger.new('/dev/null') }
  let(:base_dir) { '/rspec/repository/' }
  let(:temp) { '/temp/path/' }

  let(:repository) do
    create :repository,
           name: 'HYPE product repository debian 15.3',
           external_url: 'https://updates.suse.com/update/hype/15.3/product/'
  end

  let(:downloader) { double('downloader') }

  shared_context 'stubbed IO' do
    before do
      # Make all protected methods public here, to allow testing them properly
      described_class.send(:public, *described_class.protected_instance_methods)

      allow(repomd).to receive(:downloader).and_return(downloader)
      allow(repomd).to receive(:create_temp).with(:licenses, :metadata)
      allow(repomd).to receive(:create_dir).with(repomd.repository_dir)
      allow(repomd).to receive(:temp).and_return(temp)
    end
  end

  shared_context 'stubbed authentication' do
    before do
      allow(downloader).to receive(:auth_token)
    end
  end

  describe '#mirror_licenses' do
    include_context 'stubbed IO'
    include_context 'stubbed authentication'

    it 'downloads the directory.yast file and parses it'
    it 'downloads all referenced files'
    it 'does not fail when product.licences/directory.yast is not found'
    it 'does not create a directory when licences are not found'
  end

  describe '#mirror_metadata' do
    include_context 'stubbed IO'
    include_context 'stubbed authentication'

    let(:repomdxml) do
      RMT::Mirror::FileReference.new(
        relative_path: 'repodata/repomd.xml',
        base_dir: file_fixture('dummy_repo'),
        base_url: repomd.repository_url
      )
    end

    it 'mirrors all metadata files' do
      allow(repomd).to receive(:download_cached!)
        .with('repodata/repomd.xml', to: temp)
        .and_return(repomdxml)

      expect(repomd).to receive(:enqueue).exactly(4).times
      expect(repomd).to receive(:download_enqueued).with(no_args)

      repomd.mirror_metadata
    end

    it 'verifies repository signatures when available'
    it 'does not fail if repository signatures are not available'
    it 'raises if some whiles could not be downloaded'
  end

  describe '#mirror_packages' do
    include_context 'stubbed IO'
    include_context 'stubbed authentication'

    let(:primary_xml) { 'repodata/360c5ae3148c7e194348935b98bd80056f4fc991e0e865e4aa2fa1a541fa4805-primary.xml.gz' }
    let(:primary) do
      config = {
        relative_path: primary_xml,
        base_dir: file_fixture('dummy_repo_with_src'),
        base_url: repomd.repository_url
      }
      RMT::Mirror::FileReference.new(**config).tap { |r| r.type = :primary }
    end

    it 'mirrors all packages provided by metadata' do
      expect(repomd).to receive(:download_enqueued)

      repomd.mirror_packages([primary])

      expect(repomd.enqueued.map(&:checksum)).to match([
        '1fca3a61887d77e8231f351dd44a63110893335e04c63cc5157ff70b734f3515',
        'b1646b48996e8a0df454979679b2ad60771b01c2a25d639df398530fbad68c0a'
      ])
    end

    it 'fails if primary.xml was unparsable'
    it 'does not fail of one package could not be mirrored'
    it 'does mirror source packages if enabled'

    context 'mirroring source packages enabled'
    context 'deduplicate packages'

    context 'with deltainfo' do
      it 'merges primary and deltainfo packages'
      it 'fails if deltainfo.xml could not be parsed'
    end
  end
end
