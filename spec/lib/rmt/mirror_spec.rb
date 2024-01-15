require 'rails_helper'

RSpec.describe RMT::Mirror do
  let(:url) { 'http://some.test.us/path/directory/' }
  let(:mirroring_base_dir) { '/non/existing/' }
  let(:repository) { create :repository, external_url: url }

  let(:mirror) do
    described_class.new(repository: repository,
                        mirroring_base_dir: mirroring_base_dir,
                        logger: nil,
                        mirror_sources: false,
                        is_airgapped: false)
  end

  before do
    # Make all protected methods public for testing purpose
    described_class.send(:public, *described_class.protected_instance_methods)
  end

  describe '#repository_type' do
    let(:repomd_url) { 'http://some.test.us/path/directory/repodata/repomd.xml' }
    let(:debian_url) { 'http://some.test.us/path/directory/Release' }

    context 'authentication' do
      let(:authenticated_repo_url) { URI.join(repomd_url, '?token') }

      it 'uses the credentials from the repository if the repository has credentials' do
        stub_request(:head, authenticated_repo_url)
          .to_return(status: 200, body: '', headers: {})

        allow(repository).to receive(:auth_token).and_return('token')
        expect(RMT::HttpRequest).to receive(:new)
          .with(authenticated_repo_url, method: :head, followlocation: true)
          .and_call_original

        mirror.repository_type
      end

      it 'uses no credentials from the repository if the repository has no credentials' do
        stub_request(:head, repomd_url)
          .to_return(status: 200, body: '', headers: {})

        expect(RMT::HttpRequest).to receive(:new)
          .with(URI.parse(repomd_url), method: :head, followlocation: true)
          .and_call_original

        mirror.repository_type
      end
    end

    context 'repomd repository' do
      it 'detects a repomd repository' do
        stub_request(:head, repomd_url).to_return(status: 200, body: '', headers: {})

        expect(mirror.repository_type).to eq(:repomd)
      end

      context 'with local file as URI' do
        let(:url) { 'file:///test/export/SUSE/Products/SLE-Product-SLES/15-SP4/x86_64/product/' }
        let(:path) { File.join(URI.join(url).path, 'repodata/repomd.xml') }

        it 'checks if the file exists' do
          allow(File).to receive(:exist?).with(path).and_return(true)

          expect(mirror.repository_type).to eq(:repomd)
        end
      end
    end

    context 'debian flat repository' do
      it 'detects a flat debian repository' do
        stub_request(:head, repomd_url).to_return(status: 404, body: '', headers: {})
        stub_request(:head, debian_url).to_return(status: 200, body: '', headers: {})

        expect(mirror.repository_type).to eq(:debian)
      end
    end

    context 'unknown repository type' do
      it 'raises if a unknown repository type is detected' do
        stub_request(:head, repomd_url).to_return(status: 404, body: '', headers: {})
        stub_request(:head, debian_url).to_return(status: 404, body: '', headers: {})

        expect(mirror.repository_type).to be_nil
      end
    end
  end
end
