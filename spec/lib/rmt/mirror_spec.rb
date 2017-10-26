require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
# rubocop:disable RSpec/MultipleExpectations

RSpec.describe RMT::Mirror do
  describe '#mirror' do
    around do |example|
      @tmp_dir = Dir.mktmpdir('rmt')
      example.run
      FileUtils.remove_entry(@tmp_dir)
    end

    context 'without auth_token' do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          repository_url: 'http://localhost/dummy_repo/',
          local_path: '/dummy_repo',
          mirror_src: false
        )
      end

      before do
        VCR.use_cassette 'mirroring' do
          rmt_mirror.mirror
        end
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end
    end

    context 'with auth_token' do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          repository_url: 'http://localhost/dummy_repo/',
          local_path: '/dummy_repo',
          auth_token: 'repo_auth_token',
          mirror_src: false
        )
      end

      before do
        VCR.use_cassette 'mirroring_with_auth_token' do
          rmt_mirror.mirror
        end
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end
    end

    context 'product with license and signatures' do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token',
          mirror_src: false
        )
      end

      before do
        VCR.use_cassette 'mirroring_product' do
          rmt_mirror.mirror
        end
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_product/product/')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_product/product/')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end

      it 'downloads repomd.xml signatures' do
        ['repomd.xml.key', 'repomd.xml.asc'].each do |file|
          expect(File.size(File.join(@tmp_dir, 'dummy_product/product/repodata/', file))).to be > 0
        end
      end

      it 'downloads product license' do
        ['directory.yast', 'license.txt', 'license.de.txt', 'license.ru.txt'].each do |file|
          expect(File.size(File.join(@tmp_dir, 'dummy_product/product.license/', file))).to be > 0
        end
      end
    end

    context 'handles erroring' do
      let(:mirroring_dir) { @tmp_dir }
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: mirroring_dir,
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token',
          mirror_src: false
        )
      end

      context 'when mirroring_base_dir is not writable' do
        let(:mirroring_dir) { '/non/existent/path' }

        it 'raises exception' do
          VCR.use_cassette 'mirroring_product' do
            expect { rmt_mirror.mirror }.to raise_error(RMT::Mirror::Exception)
          end
        end
      end

      context "when can't create tmp dir" do
        before { allow(Dir).to receive(:mktmpdir).and_raise('mktmpdir exception') }
        it 'handles the exception' do
          VCR.use_cassette 'mirroring_product' do
            expect { rmt_mirror.mirror }.to raise_error(RMT::Mirror::Exception)
          end
        end
      end

      context "when can't download metadata" do
        before { allow_any_instance_of(RMT::Downloader).to receive(:download).and_raise(RMT::Downloader::Exception) }
        it 'handles RMT::Downloader::Exception' do
          VCR.use_cassette 'mirroring_product' do
            expect { rmt_mirror.mirror }.to raise_error(RMT::Mirror::Exception)
          end
        end
      end

      context "when can't parse metadata" do
        before { allow_any_instance_of(RMT::Rpm::RepomdXmlParser).to receive(:parse).and_raise('Parse error') }
        it 'removes the temporary metadata directory' do
          VCR.use_cassette 'mirroring_product' do
            expect { rmt_mirror.mirror }.to raise_error(RuntimeError)
            expect(File.exist?(rmt_mirror.instance_variable_get(:@repodata_dir))).to be(false)
          end
        end
      end
    end
  end
end
