require 'rails_helper'

RSpec.describe RMT::Mirror::Repomd do
  subject(:repomd) { described_class.new(**repomd_mirror_configuration) }

  let(:logger) { RMT::Logger.new('/dev/null') }

  # Remember that RMT forces a trialing slash on all repository URLS!
  let(:repository_url) { 'https://updates.suse.com/sample/repository/15.4/product/' }
  let(:repository) do
    create :repository,
           name: 'SUSE Linux Enterprise Server 15 SP4',
           external_url: repository_url
  end

  # Configuration for Debian mirroring instance
  let(:base_dir) { '/test/repository/base/path/' }
  let(:repomd_mirror_configuration) do
    {
      repository: repository,
      logger: logger,
      mirroring_base_dir: base_dir
    }
  end

  # Configuration for file reference to an arbitrary fixture
  let(:fixture) { 'repodata/repomd.xml' }
  let(:file_ref_configuration) do
    {
      relative_path: fixture,
      base_dir: file_fixture('dummy_repo/'),
      base_url: 'https://updates.suse.com/sample/repository/15.4/'
    }
  end
  let(:repomd_ref) { RMT::Mirror::FileReference.new(**file_ref_configuration) }

  before do
    described_class.send(:public, *described_class.protected_instance_methods)
  end

  describe '#mirror_implementation' do
    let(:licenses) { instance_double(RMT::Mirror::License) }

    before do
      allow(RMT::Mirror::License).to receive(:new).and_return(licenses)
      allow(repomd).to receive(:temp).with(:metadata).and_return('a')
    end

    it 'mirrors the whole repository' do
      expect(repomd).to receive(:create_repository_path)
      expect(repomd).to receive(:create_temp_dir).with(:metadata)
      expect(licenses).to receive(:mirror)
      expect(repomd).to receive(:mirror_metadata)
      expect(repomd).to receive(:mirror_packages)
      expect(repomd).to receive(:move_files).with(glob: 'a/repodata/*', destination: repomd.repository_path('repodata'), clean_before: true)

      repomd.mirror_implementation
    end

    context 'non-product repositories' do
      let(:repository_url) { 'https://updates.suse.com/sample/repository/15.4/update' }

      it 'does not mirror licenses' do
        expect(repomd).to receive(:create_repository_path)
        expect(repomd).to receive(:create_temp_dir).with(:metadata)
        expect(repomd).to receive(:mirror_metadata)
        expect(repomd).to receive(:mirror_packages)
        expect(repomd).to receive(:move_files).with(glob: 'a/repodata/*', destination: repomd.repository_path('repodata'), clean_before: true)

        expect(licenses).not_to receive(:mirror)

        repomd.mirror_implementation
      end
    end
  end

  describe '#mirror_metadata' do
    let(:ref_configuration) do
      {
        base_dir: base_dir,
        base_url: 'https://updates.suse.com/sample/repository/15.4/',
        cache_dir: repomd.repository_path
      }
    end
    let(:signature_file) { RMT::Mirror::FileReference.new(relative_path: 'repodata/repomd.xml.asc', **ref_configuration) }
    let(:key_file) { RMT::Mirror::FileReference.new(relative_path: 'repodata/repomd.xml.key', **ref_configuration) }
    let(:parsed_repomd) { RepomdParser::RepomdXmlParser.new.parse_file(repomd_ref.local_path) }

    before do
      allow(repomd).to receive(:temp).with(:metadata).and_return('a')
    end

    it 'checks signature of the repomd file' do
      allow(repomd).to receive(:download_cached!).and_return(repomd_ref)
      allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_return([])
      allow(repomd).to receive(:enqueue)
      allow(repomd).to receive(:download_enqueued)
      expect(repomd).to receive(:check_signature).with(key_file: duck_type(:local_path), signature_file: duck_type(:local_path),
                                                       metadata_file: duck_type(:local_path))
      repomd.mirror_metadata
    end

    it 'parses the repomd file' do
      allow(repomd).to receive(:download_cached!).and_return(repomd_ref)
      allow(repomd).to receive(:check_signature)
      allow(repomd).to receive(:download_enqueued)
      allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse_file).with(repomd_ref.local_path).and_return(parsed_repomd)
      expect(repomd).to receive(:enqueue).with(duck_type(:local_path)).exactly(4).times

      metadatas = repomd.mirror_metadata
      expect(metadatas.count).to eq(4)
    end

    it 'downloads the metadata files' do
      allow(repomd).to receive(:download_cached!).and_return(repomd_ref)
      allow(repomd).to receive(:check_signature)
      allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_return([])
      allow(repomd).to receive(:enqueue)
      expect(repomd).to receive(:download_enqueued)
      repomd.mirror_metadata
    end

    it 'handles generic errors' do
      allow(repomd).to receive(:download_cached!).and_return(repomd_ref)
      allow(repomd).to receive(:check_signature)
      allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_raise(StandardError)
      expect { repomd.mirror_metadata }.to raise_exception(RMT::Mirror::Exception, /Error while mirroring/)
    end
  end

  describe '#parse_packages_metadata' do
    let(:fixture) { 'repodata/repomd.xml' }
    let(:fixture_base_dir) { file_fixture('dummy_repo') }
    let(:repomd_package_ref) do
      RMT::Mirror::FileReference.new(**file_ref_configuration).tap do |ref|
        ref.type = type
      end
    end

    let(:delta_parser_double) { instance_double(RepomdParser::DeltainfoXmlParser) }
    let(:primary_parser_double) { instance_double(RepomdParser::PrimaryXmlParser) }

    let(:metadata_refs) do
      [repomd_package_ref]
    end

    context 'valid repomd file' do
      context 'with deltainfo files' do
        let(:fixture) { 'repodata/a546b430098b8a3fb7d65493a9ce608fafcb32f451d0ce8bf85410191f347cc3-deltainfo.xml.gz' }
        let(:type) { :deltainfo }

        it 'parses' do
          expect_any_instance_of(RepomdParser::DeltainfoXmlParser).to receive :parse
          repomd.parse_packages_metadata(metadata_refs)
        end
      end

      context 'with primary package files' do
        let(:fixture) { 'repodata/abf421e45af5cd686f050bab3d2a98e0a60d1b5ca3b07c86cb948fc1abfa675e-primary.xml.gz' }
        let(:type) { :primary }

        it 'parses primary package files' do
          expect_any_instance_of(RepomdParser::PrimaryXmlParser).to receive :parse
          repomd.parse_packages_metadata(metadata_refs)
        end
      end
    end
  end

  describe '#mirror_packages' do
    let(:fixture) { 'repodata/abf421e45af5cd686f050bab3d2a98e0a60d1b5ca3b07c86cb948fc1abfa675e-primary.xml.gz' }
    let(:primary_ref) { RMT::Mirror::FileReference.new(**file_ref_configuration).tap { |ref| ref.type = :primary } }
    let(:package_ref) { instance_double(RMT::Mirror::FileReference) }

    it 'downloads the reference packages' do
      allow(repomd).to receive(:need_to_download?).and_return(true)
      allow(repomd).to receive(:download_enqueued).with(continue_on_error: true).and_return([])

      expect(repomd).to receive(:enqueue).exactly(4).times

      repomd.mirror_packages([primary_ref])
    end

    it 'raises an error on failed downloads' do
      allow(repomd).to receive(:need_to_download?).and_return(true)
      allow(repomd).to receive(:download_enqueued).with(continue_on_error: true).and_return([package_ref])

      expect(repomd).to receive(:enqueue).exactly(4).times

      expect { repomd.mirror_packages([primary_ref]) }.to raise_exception(RMT::Mirror::Exception, /Error while mirroring packages: Failed to download 1 files/)
    end
  end
end
