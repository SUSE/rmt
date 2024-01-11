require 'rails_helper'

describe RMT::Mirror::Debian do
  subject(:debian) { described_class.new(**configuration) }

  let(:repository) do
    create :repository,
           name: 'HYPE product repository debian 15.3',
           external_url: 'https://updates.suse.com/sample/repository/15.3/'
  end

  # Configuration for Debian mirroring instance
  let(:mirroring_base_dir) { '/test/repository/base/path/' }
  let(:configuration) do
    {
      repository: repository,
      logger: RMT::Logger.new('/dev/null'),
      mirroring_base_dir: mirroring_base_dir
    }
  end

  # Configuration for file reference to an arbitrary fixture
  let(:fixture) { 'Packages.gz' }
  let(:packages_configuration) do
    {
      relative_path: fixture,
      base_dir: file_fixture('debian/'),
      base_url: 'https://updates.suse.de/Debian/'
    }
  end
  let(:packages_ref) { RMT::Mirror::FileReference.new(**packages_configuration) }

  describe '#mirror_implementation' do
    let(:temp) { '/tmp/metadata/' }

    it 'mirrors the whole repository' do
      described_class.send(:public, *described_class.protected_instance_methods)
      allow(debian).to receive(:temp).with(:metadata).and_return(temp)
      allow(debian).to receive(:mirror_metadata).and_return([packages_ref])

      expect(debian).to receive(:create_repository_path)
      expect(debian).to receive(:create_temp_dir)
      expect(debian).to receive(:mirror_packages).with([packages_ref])
      expect(debian).to receive(:copy_directory_content).with(
        source: File.join(temp, '*'),
        destination: debian.repository_path
      )
      debian.mirror_implementation
    end
  end

  describe '#mirror_implementation' do
    before do
      allow(debian).to receive(:temp).with(:metadata).and_return('bar')
    end

    it 'mirrors the metadata' do
      allow(debian).to receive(:create_temp_dir).with(:metadata)
      expect(debian).to receive(:mirror_metadata)
      allow(debian).to receive(:mirror_packages)
      allow(debian).to receive(:copy_directory_content)
      debian.mirror_implementation
    end

    it 'mirrors the packages' do
      allow(debian).to receive(:create_temp_dir).with(:metadata)
      allow(debian).to receive(:mirror_metadata).and_return([])
      expect(debian).to receive(:mirror_packages)
      allow(debian).to receive(:copy_directory_content)
      debian.mirror_implementation
    end

    it 'moves the files to correct directories' do
      allow(debian).to receive(:create_temp_dir).with(:metadata)
      allow(debian).to receive(:mirror_metadata).and_return([])
      allow(debian).to receive(:mirror_packages)
      expect(debian).to receive(:copy_directory_content)
      debian.mirror_implementation
    end
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
      let(:release_path) { described_class::RELEASE_FILE_NAME }

      it 'downloads and parses the file' do
        expect(debian).to receive(:download_cached!).with(release_path, to: 'bar')
        expect(debian).to receive(:check_signature)
        expect(debian).to receive(:download_enqueued)
        debian.mirror_metadata
      end
    end
  end

  describe '#mirror_packages' do
    let(:fixture) { 'Packages.gz' }
    let(:non_package_ref) do
      packages_ref.dup.tap do |ref|
        ref.relative_path = 'Packages'
      end
    end

    it 'download packages to disk' do
      expect(debian).to receive(:enqueue).exactly(4).times
      expect(debian).to receive(:parse_package_list).with(packages_ref).and_call_original
      expect(debian).to receive(:download_enqueued)
      debian.mirror_packages([packages_ref, non_package_ref])
    end

    it 'does not download the file if not needed' do
      expect(debian).to receive(:need_to_download?).exactly(3).times.and_return(true)
      expect(debian).to receive(:need_to_download?).with(any_args) { |ref| ref.size == 206796 }.and_return(false)
      expect(debian).to receive(:enqueue).exactly(3).times
      expect(debian).to receive(:parse_package_list).with(packages_ref).and_call_original
      expect(debian).to receive(:download_enqueued)
      debian.mirror_packages([packages_ref])
    end
  end

  describe '#parse_package_list' do
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
