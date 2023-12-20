require 'rails_helper'

RSpec.describe RMT::Mirror do
  let(:url) { 'http://some.test.us/path/directory/' }
  let(:base_dir) { '/non/existing/' }
  let(:repository) { create :repository, external_url: url }

  let(:mirror) do
    described_class.new(repository: repository,
                        base_dir: base_dir,
                        logger: nil,
                        mirror_sources: false,
                        is_airgapped: false)
  end

  describe '#detect_repository_type' do
    let(:repomd_url) { 'http://some.test.us/path/directory/repodata/repomd.xml' }
    let(:debian_url) { 'http://some.test.us/path/directory/Release' }

    context 'repomd repository' do
      it 'detects a repomd repository' do
        stub_request(:head, repomd_url).to_return(status: 200, body: '', headers: {})

        expect(mirror.detect_repository_type).to eq(:repomd)
      end
    end

    context 'debian flat repository' do
      it 'detects a flat debian repository' do
        stub_request(:head, repomd_url).to_return(status: 404, body: '', headers: {})
        stub_request(:head, debian_url).to_return(status: 200, body: '', headers: {})

        expect(mirror.detect_repository_type).to eq(:debian)
      end
    end

    context 'unknown repository type' do
      it 'raises if a unknown repository type is detected' do
        stub_request(:head, repomd_url).to_return(status: 404, body: '', headers: {})
        stub_request(:head, debian_url).to_return(status: 404, body: '', headers: {})

        expect(mirror.detect_repository_type).to be_nil
      end
    end
  end
end
