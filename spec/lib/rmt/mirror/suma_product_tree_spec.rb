require 'rails_helper'

RSpec.describe RMT::Mirror::SumaProductTree do
  subject(:suma) { described_class.new(**suma_mirror_configuration) }

  let(:mirroring_base_dir) { '/tmp' }
  let(:base_dir) { File.join(mirroring_base_dir, '/suma/') }

  shared_examples 'mirror SUMA product tree' do
    it 'mirrors the product_tree file' do
      expect(downloader).to receive(:download_multi).with(
        [
          have_attributes(
            relative_path: 'product_tree.json',
            base_url: base_url,
            base_dir: base_dir
          )
        ]
      )

      suma.mirror
    end

    context 'when an error occurs downloading the file' do
      it 'raises a proper exception' do
        expect(downloader).to receive(:download_multi).and_raise(RMT::Downloader::Exception, 'Network issues')

        expect { suma.mirror }.to raise_error(RMT::Mirror::Exception, /Could not mirror SUSE Manager/)
      end
    end
  end

  describe '#mirror' do
    before do
      allow(RMT::Downloader).to receive(:new).and_return downloader
    end

    let(:downloader) { instance_double RMT::Downloader }

    context "when 'scc.host' is not set on the configuration file" do
      before do
        allow(Settings).to receive(:try).with(:scc).and_return(nil)
      end

      it_behaves_like 'mirror SUMA product tree' do
        let(:suma_mirror_configuration) do
          {
            logger: RMT::Logger.new('/dev/null'),
            mirroring_base_dir: mirroring_base_dir
          }
        end
        let(:base_url) { 'https://scc.suse.com/suma/' }
      end
    end

    context "when 'scc.host' is set on the configuration file" do
      before do
        allow(Settings).to receive(:try).with(:scc).and_return(scc_config)
        allow(scc_config).to receive(:try).with(:host).and_return('http://local.scc/connect')
      end

      let(:scc_config) { instance_double(Config::Options) }

      it_behaves_like 'mirror SUMA product tree' do
        let(:suma_mirror_configuration) do
          {
            logger: RMT::Logger.new('/dev/null'),
            mirroring_base_dir: mirroring_base_dir
          }
        end
        let(:base_url) { 'http://local.scc/suma/' }
      end
    end

    context "when an URL is passed as an argument and 'scc.host' is set" do
      before do
        allow(Settings).to receive(:try).with(:scc).and_return(scc_config)
        allow(scc_config).to receive(:try).with(:host).and_return('http://local-scc.com/connect')
      end

      let(:scc_config) { instance_double(Config::Options) }

      it_behaves_like 'mirror SUMA product tree' do
        let(:suma_mirror_configuration) do
          {
            logger: RMT::Logger.new('/dev/null'),
            mirroring_base_dir: mirroring_base_dir,
            url: base_url
          }
        end
        let(:base_url) { 'http://custom-scc.com:3000/suma/' }
      end
    end
  end
end
