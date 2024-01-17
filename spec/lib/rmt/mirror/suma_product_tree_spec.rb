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
      base_url: described_class::FILE_URL,
      cache_dir: nil,
      base_dir: File.join(base_dir, '/suma/')
    }
  end

  let(:base_dir) { '/tmp' }
  let(:downloader) { instance_double RMT::Downloader }

  describe '#mirror' do
    before do
      allow(suma).to receive(:downloader).and_return downloader
    end

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
end
