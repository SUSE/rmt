require 'rails_helper'

RSpec.describe RMT::Mirror::SumaProductTree do
  subject(:suma) { described_class.new(**suma_mirror_configuration) }

  let(:suma_mirror_configuration) do
    {
      logger: RMT::Logger.new('/dev/null'),
      mirroring_base_dir: base_dir
    }
  end
  let(:ref_configuration) do
    {
      relative_path: 'product_tree.json',
      base_url: base_url,
      cache_dir: nil,
      base_dir: File.join(base_dir, '/suma/')
    }
  end

  let(:base_dir) { '/tmp' }
  let(:downloader) { instance_double RMT::Downloader }

  shared_examples 'mirror SUMA product tree' do
    it 'mirrors the product_tree file' do
      expect(RMT::Mirror::FileReference).to receive(:new).with(**ref_configuration)
      expect(downloader).to receive(:download_multi)
      suma.mirror
    end

    it 'fails to mirror the product file' do
      expect(downloader).to receive(:download_multi).and_raise(RMT::Downloader::Exception, 'Network issues')
      expect { suma.mirror }.to raise_error(RMT::Mirror::Exception, /Could not mirror SUSE Manager/)
    end

    context 'with default mirror dir' do
      let(:updated_base_dir) { File.expand_path(File.join(RMT::DEFAULT_MIRROR_DIR, '/../')) }
      let(:base_dir) { File.join(updated_base_dir, '/suma/') }

      it 'alters the default mirroring path' do
        expect(RMT::Mirror::FileReference).to receive(:new).with(**ref_configuration)
        expect(downloader).to receive(:download_multi)
        suma.mirror
      end
    end
  end

  describe '#mirror' do
    before do
      allow(RMT::Downloader).to receive(:new).and_return downloader
    end

    context 'with default SUMA product tree URL' do
      before do
        allow(Settings).to receive(:try).with(:mirroring).and_return(nil)
      end

      it_behaves_like 'mirror SUMA product tree' do
        let(:base_url) { 'https://scc.suse.com/suma/' }
      end
    end

    context 'with custom SUMA product tree URL' do
      before do
        allow(Settings).to receive(:try).with(:mirroring).and_return(mirroring_configuration)
        allow(mirroring_configuration).to receive(:try)
          .with(:suma_product_tree_base_url).and_return(base_url)
      end

      let(:mirroring_configuration) { instance_double(Config::Options) }

      it_behaves_like 'mirror SUMA product tree' do
        let(:base_url) { 'http://localhost:3000/suma/' }
      end
    end
  end
end
