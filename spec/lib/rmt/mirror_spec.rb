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

      # it 'continues checking repo if fi'
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

    context 'debian repository' do
      it 'detects a debian repository' do
        stub_request(:head, repomd_url).to_return(status: 404, body: '', headers: {})
        stub_request(:head, debian_url).to_return(status: 200, body: '', headers: {})

        expect(mirror.repository_type).to eq(:debian)
      end
    end

    context 'local file as URI' do
      let(:url) { 'file:///test/export/SUSE/Products/SLE-Product-SLES/15-SP4/x86_64/product/' }
      let(:path_repomd) { File.join(URI.join(url).path, 'repodata/repomd.xml') }
      let(:path_debian) { File.join(URI.join(url).path, 'Release') }

      it 'continues checking for repository type' do
        allow(File).to receive(:exist?).with(path_repomd).and_return(false)
        allow(File).to receive(:exist?).with(path_debian).and_return(true)

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

  describe '#mirror_now' do
    context 'repomd repository' do
      let(:repomd_mirror) { instance_double('RMT::Mirror::Repomd') }

      before do
        allow(mirror).to receive(:repository_type).and_return(:repomd)
        allow(RMT::Mirror::Repomd).to receive(:new).and_return(repomd_mirror)
      end

      it 'creates a repomd mirror instance and calls mirror' do
        expect(repomd_mirror).to receive(:mirror)
        mirror.mirror_now
      end
    end

    context 'debian repository' do
      let(:debian_mirror) { instance_double('RMT::Mirror::Debian') }

      before do
        allow(mirror).to receive(:repository_type).and_return(:debian)
        allow(RMT::Mirror::Debian).to receive(:new).and_return(debian_mirror)
      end

      it 'creates a debian mirror instance and calls mirror' do
        expect(debian_mirror).to receive(:mirror)
        mirror.mirror_now
      end
    end

    it 'raises an exception if the repository type is unknown' do
      allow(mirror).to receive(:repository_type).and_return(nil)
      expect { mirror.mirror_now }.to raise_error(RMT::Mirror::Exception)
    end
  end
end
