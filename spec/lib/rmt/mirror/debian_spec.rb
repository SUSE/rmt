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
end
