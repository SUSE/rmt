require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::Downloader do
  let(:dir) { Dir.mktmpdir }
  let(:downloader) { described_class.new('http://example.com', dir) }
  let(:headers) { { 'User-Agent' => "RMT/#{RMT::VERSION}" } }

  describe '#download' do
    context 'when HTTP code is not 200' do
      before do
        stub_request(:get, 'http://example.com/rpmmd.xml')
          .with(headers: headers)
          .to_return(status: 404, body: '', headers: {})
      end

      it 'raises an exception' do
        expect do
          downloader.download('/rpmmd.xml')
        end.to raise_error(RMT::Downloader::Exception, 'HTTP request failed with code 404')
      end
    end

    context 'when HTTP code is 200' do
      let(:content) { 'test' }
      let(:checksum_type) { 'SHA256' }
      let(:checksum) { Digest.const_get(checksum_type).hexdigest(content) }

      before do
        stub_request(:get, 'http://example.com/rpmmd.xml')
          .with(headers: headers)
          .to_return(status: 200, body: 'test', headers: {})
      end

      context 'and hash function is unknown' do
        it 'raises an exception' do
          expect do
            downloader.download('/rpmmd.xml', 'CHUNKYBACON42', '0xDEADBEEF')
          end.to raise_error(RMT::Downloader::Exception, 'Unknown hash function CHUNKYBACON42')
        end
      end

      context 'and checksum is wrong' do
        it 'raises an exception' do
          expect do
            downloader.download('/rpmmd.xml', 'SHA256', '0xDEADBEEF')
          end.to raise_error(RMT::Downloader::Exception, 'Checksum doesn\'t match')
        end
      end

      context 'and checksum is correct' do
        subject { downloader.download('/rpmmd.xml', checksum_type, checksum) }

        it('has correct content') { expect(File.read(subject)).to eq(content) }
      end
    end
  end

  describe '#download_multi' do
    let(:files) { %w(package1 package2 package3) }
    let(:checksum_type) { 'SHA256' }
    let(:queue) do
      queue = []
      files.each do |file|
        queue << RMT::Rpm::FileEntry.new(
          file,
          checksum_type,
          Digest.const_get(checksum_type).hexdigest(file),
          :rpm
        )
      end
      queue
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

end
