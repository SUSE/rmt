require 'rails_helper'

describe RMT::Mirror::Debian do
  subject(:debian) { described_class.new(**configuration) }

  let(:base_dir) { '/test/repository/base/path/' }
  let(:configuration) do
    {
      repository: repository,
      logger: RMT::Logger.new('/dev/null'),
      mirroring_base_dir: base_dir
    }
  end

  let(:repository) do
    create :repository,
           name: 'HYPE product repository debian 15.3',
           external_url: 'https://updates.suse.com/sample/repository/15.3/'
  end

  describe '#mirror_metadata' do
    let(:config) do
      {
        relative_path: 'Release',
        base_dir: file_fixture('debian/'),
        base_url: 'https://updates.suse.de/Debian/'
      }
    end
    let(:release_ref) { RMT::Mirror::FileReference.new(**config) }

    before do
      allow(debian).to receive(:temp).with(:metadata).and_return('bar')
      allow(debian).to receive(:download_cached!).and_return(release_ref)
    end

    it 'succeeds' do
      allow(debian).to receive(:check_signature)
      allow(debian).to receive(:parse_release_file).and_return([])
      expect(debian).to receive(:download_enqueued)
      debian.mirror_metadata
    end

    context 'mirrors the Release file' do
      let(:release_url) { File.join(repository.external_url, described_class::RELEASE_FILE_NAME) }

      it 'downloads and parses the file' do
        expect(debian).to receive(:download_cached!).with(release_url, to: 'bar')
        expect(debian).to receive(:check_signature)
        expect(debian).to receive(:download_enqueued)
        debian.mirror_metadata
      end
    end
  end

  describe '#mirror_packages' do
    it 'download packages to disk'
    it 'do not download packages which size match locally and remotly'
    it 'deduplicate obsolete references'
  end

  describe '#parse_package_list' do
    let(:config) do
      {
        relative_path: fixture,
        base_dir: file_fixture('debian/'),
        base_url: 'https://updates.suse.de/Debian/'
      }
    end
    let(:packages_ref) { RMT::Mirror::FileReference.new(**config) }

    context 'valid package list' do
      let(:fixture) { 'Packages.gz' }
      let(:deb_file_path) { '/test/repository/base/path/sample/repository/15.3/amd64/venv-salt-minion_3006.0-2.6.3_amd64.deb' }

      it 'parse package list into references' do
        packages = debian.parse_package_list(packages_ref)
        expect(packages.count).to be(4)
        expect(packages[3].local_path).to eq(deb_file_path)
        expect(packages[3].size).to eq(23333144)
      end
    end

    context 'malformed package list' do
      let(:fixture) { 'Invalid_Packages.gz' }

      it 'is parsed partially' do
        expect { debian.parse_package_list(packages_ref) }.to raise_error(RMT::Mirror::Exception, /unexpected end of file/)
      end
    end
  end

  describe '#parse_release_file' do
    let(:config) do
      {
        relative_path: rel_path,
        base_dir: file_fixture('debian/'),
        base_url: 'https://updates.suse.de/Debian/'
      }
    end
    let(:release_ref) { RMT::Mirror::FileReference.new(**config) }

    context 'Release file is valid' do
      let(:rel_path) { 'Release' }
      let(:local_path) { 'spec/fixtures/files/debian/Packages' }
      let(:remote_path) { 'https://updates.suse.de/Debian/Packages' }

      it 'parses the file' do
        metadata = debian.parse_release_file(release_ref)
        expect(metadata.length).to eq 2
        expect(metadata[0].local_path).to eq local_path
        expect(metadata[0].remote_path.to_s).to eq remote_path
      end
    end

    context 'Release file is invalid' do
      let(:rel_path) { 'Invalid_Release' }

      it 'returns empty metadata' do
        expect(debian.parse_release_file(release_ref)).to be_empty
      end
    end
  end
end
