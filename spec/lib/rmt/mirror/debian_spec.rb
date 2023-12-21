require 'rails_helper'

describe RMT::Mirror::Debian do
  subject(:debian) { described_class.new(**configuration) }

  let(:configuration) do
    {
      repository: repository,
      logger: RMT::Logger.new('/dev/null'),
      mirroring_base_dir: '/rspec/repository'
    }
  end

  let(:repository) do
    create :repository,
           name: 'HYPE product repository debian 15.3',
           external_url: 'https://updates.suse.com/update/hype/15.3/product/'
  end

  describe 'Debian mirroring' do
    context 'mirrors the Release file' do
      let(:release_url) { File.join(repository.external_url, described_class::RELEASE_FILE_NAME) }

      it 'downloads and parses the file' do
        allow(debian).to receive(:temp).with(:metadata).and_return('bar')
        expect(debian).to receive(:create_temp_dir).with(:metadata)
        expect(debian).to receive(:download_cached!).with(release_url, to: 'bar')
        debian.mirror
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
