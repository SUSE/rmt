require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::Downloader do
  let(:dir) { Dir.mktmpdir }
  let(:downloader) { described_class.new(repository_url: 'http://example.com', local_path: dir) }
  let(:headers) { { 'User-Agent' => "RMT/#{RMT::VERSION}" } }

  describe '#download over http://' do
    context 'when HTTP code is not 200' do
      before do
        stub_request(:get, 'http://example.com/repomd.xml')
          .with(headers: headers)
          .to_return(status: 404, body: '', headers: {})
      end

      it 'raises an exception' do
        expect do
          downloader.download('/repomd.xml')
        end.to raise_error(RMT::Downloader::Exception, '/repomd.xml - HTTP request failed with code 404')
      end
    end

    context 'when processing response by Typhoeus failed' do
      before do
        stub_request(:get, 'http://example.com/repomd.xml')
          .with(headers: headers)
          .to_return(status: 200, body: '', headers: {})
      end

      it 'raises an exception' do
        allow_any_instance_of(RMT::FiberRequest).to receive(:receive_body) do
          response_double = double
          allow(response_double).to receive(:return_code) { :error }
          response_double
        end

        expect do
          downloader.download('/repomd.xml')
        end.to raise_error(RMT::Downloader::Exception, '/repomd.xml - return code error')
      end
    end

    context 'when HTTP code is 200' do
      let(:content) { 'test' }
      let(:checksum_type) { 'SHA256' }
      let(:checksum) { Digest.const_get(checksum_type).hexdigest(content) }

      before do
        stub_request(:get, 'http://example.com/repomd.xml')
          .with(headers: headers)
          .to_return(status: 200, body: 'test', headers: {})
      end

      context 'and hash function is unknown' do
        it 'raises an exception' do
          expect do
            downloader.download('/repomd.xml', 'CHUNKYBACON42', '0xDEADBEEF')
          end.to raise_error(RMT::Downloader::Exception, 'Unknown hash function CHUNKYBACON42')
        end
      end

      context 'and checksum is wrong' do
        it 'raises an exception' do
          expect do
            downloader.download('/repomd.xml', 'SHA256', '0xDEADBEEF')
          end.to raise_error(RMT::Downloader::Exception, 'Checksum doesn\'t match')
        end
      end

      context 'and checksum is correct' do
        let(:filename) { downloader.download('/repomd.xml', checksum_type, checksum) }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end
    end

    context 'with auth_token' do
      let(:downloader) { described_class.new(repository_url: 'http://example.com', local_path: dir, auth_token: 'repo_auth_token') }
      let(:content) { 'test' }

      before do
        stub_request(:get, 'http://example.com/repomd.xml?repo_auth_token')
          .with(headers: headers)
          .to_return(status: 200, body: content, headers: {})
      end

      context 'and checksum is correct' do
        let(:filename) { downloader.download('/repomd.xml') }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end

      context 'and checksum type is SHA and it is is correct' do
        let(:filename) { downloader.download('/repomd.xml') }
        let(:checksum_type) { 'sha' }
        let(:checksum) { Digest.const_get('SHA1').hexdigest(content) }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end
    end
  end

  describe '#download over file://' do
    subject(:download) { downloader.download('repodata/repomd.xml') }

    let(:dir2) { Dir.mktmpdir }
    let(:path) { 'file://' + File.expand_path(file_fixture('dummy_repo/')) + '/' }
    let(:downloader) { described_class.new(repository_url: path, local_path: dir2) }

    # WebMock doesn't work nicely with file://
    around do |example|
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end

    it 'saves the file when it exists' do
      expect(File.size(download)).to eq(File.size(file_fixture('dummy_repo/repodata/repomd.xml')))
    end

    context "when file doesn't exist" do
      let(:path) { 'file://' + File.expand_path(file_fixture('.')) + '/non_existent/' }

      it 'raises and exception' do
        expect do
          downloader.download('/repodata/repomd.xml')
        end.to raise_error(RMT::Downloader::Exception, '/repodata/repomd.xml - File does not exist')
      end
    end
  end

  describe '#download_multi' do
    let(:files) { %w[package1 package2 package3] }
    let(:checksum_type) { 'SHA256' }
    let(:queue) do
      files.map do |file|
        RMT::Rpm::FileEntry.new(
          file,
          checksum_type,
          Digest.const_get(checksum_type).hexdigest(file),
          :rpm
        )
      end
    end

    before do
      files.each do |file|
        stub_request(:get, "http://example.com/#{file}").with(headers: headers)
          .to_return(status: 200, body: file, headers: {})
      end
      downloader.download_multi(queue)
    end

    it 'requested all files' do
      files.each do |file|
        expect(WebMock).to(
          have_requested(:get, "http://example.com/#{file}").with(headers: headers)
        )
      end
    end

    it 'saved all files' do
      files.each do |file|
        content = File.read(File.join(dir, file))
        expect(content).to eq(file)
      end
    end
  end

  describe '#download_multi handles exceptions properly' do
    let(:files) { %w[package1 package2 package3] }
    let(:checksum_type) { 'SHA256' }
    let(:queue) do
      files.map do |file|
        RMT::Rpm::FileEntry.new(
          file,
          checksum_type,
          Digest.const_get(checksum_type).hexdigest(file),
          :rpm
        )
      end
    end

    before do
      files.each do |file|
        stub_request(:get, "http://example.com/#{file}").with(headers: headers)
          .to_return(status: 404, body: file, headers: {})
      end
      downloader.download_multi(queue)
    end

    it 'requested all files' do
      files.each do |file|
        expect(WebMock).to(
          have_requested(:get, "http://example.com/#{file}").with(headers: headers)
        )
      end
    end

    it 'but no files were actually saved' do
      files.each do |file|
        expect(File.exist?(File.join(dir, file))).to eq(false)
      end
    end
  end
end
