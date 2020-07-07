require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::Downloader do
  let(:dir) { Dir.mktmpdir }
  let(:downloader) { described_class.new(repository_url: 'http://example.com', destination_dir: dir, logger: RMT::Logger.new('/dev/null')) }
  let(:headers) { { 'User-Agent' => "RMT/#{RMT::VERSION}" } }

  after do
    FileUtils.remove_entry(dir)
  end

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
        allow_any_instance_of(RMT::FiberRequest).to receive(:read_body) do
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
            downloader.download('/repomd.xml', checksum_type: 'CHUNKYBACON42', checksum_value: '0xDEADBEEF')
          end.to raise_error(RMT::ChecksumVerifier::Exception, 'Unknown hash function CHUNKYBACON42')
        end
      end

      context 'and checksum is wrong' do
        it 'raises an exception' do
          expect do
            downloader.download('/repomd.xml', checksum_type: 'SHA256', checksum_value: '0xDEADBEEF')
          end.to raise_error(RMT::ChecksumVerifier::Exception, 'Checksum doesn\'t match')
        end
      end

      context 'and checksum is correct' do
        let(:filename) { downloader.download('/repomd.xml', checksum_type: checksum_type, checksum_value: checksum) }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end
    end

    context 'with auth_token' do
      let(:downloader) do
        described_class.new(
          repository_url: 'http://example.com',
          destination_dir: dir,
          logger: RMT::Logger.new('/dev/null'),
          auth_token: 'repo_auth_token'
        )
      end
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

    describe '#download with If-Modified-Since' do
      let(:cache_dir) { Dir.mktmpdir }
      let(:repo_dir) { Dir.mktmpdir }
      let(:downloader) do
        described_class.new(
          repository_url: 'http://example.com',
          destination_dir: repo_dir,
          logger: RMT::Logger.new('/dev/null'),
          cache_dir: cache_dir
        )
      end
      let(:time) { Time.utc(2018, 1, 1, 10, 10, 0) }
      let(:if_modified_headers) do
        {
          'User-Agent' => "RMT/#{RMT::VERSION}",
          'If-Modified-Since' => 'Mon, 01 Jan 2018 10:10:00 GMT'
        }
      end
      let(:filename) { 'repomd.xml' }
      let(:downloaded_file) { downloader.download("/#{filename}") }
      let(:cached_content) { 'cached_content' }
      let(:fresh_content) { 'fresh_content' }

      after do
        FileUtils.remove_entry(cache_dir)
        FileUtils.remove_entry(repo_dir)
      end

      context 'a file exists in cache and not modified' do
        before do
          fn = File.join(cache_dir, filename)
          File.open(fn, 'w') { |file| file.write(cached_content) }
          File.utime(time, time, fn)
          stub_request(:get, "http://example.com/#{filename}")
              .with(headers: if_modified_headers)
              .to_return(status: 304, body: '', headers: {})
        end

        it('has correct content') { expect(File.read(downloaded_file)).to eq(cached_content) }
      end

      context 'a file exists in cache and is modified' do
        before do
          fn = File.join(cache_dir, filename)
          File.open(fn, 'w') { |file| file.write(cached_content) }
          File.utime(time, time, fn)
          stub_request(:get, "http://example.com/#{filename}")
              .with(headers: if_modified_headers)
              .to_return(status: 200, body: fresh_content, headers: {})
        end

        it('has correct content') { expect(File.read(downloaded_file)).to eq(fresh_content) }
      end

      context "a file doesn't exist in cache" do
        let(:filename) { 'another_file.xml' }

        before do
          stub_request(:get, "http://example.com/#{filename}")
              .with(headers: headers)
              .to_return(status: 200, body: fresh_content, headers: {})
        end

        it('has correct content') { expect(File.read(downloaded_file)).to eq(fresh_content) }
      end
    end
  end

  describe '#download over file://' do
    subject(:download) { downloader.download('repodata/repomd.xml') }

    let(:dir2) { Dir.mktmpdir }
    let(:path) { 'file://' + File.expand_path(file_fixture('dummy_repo/')) + '/' }
    let(:downloader) { described_class.new(repository_url: path, destination_dir: dir2, logger: RMT::Logger.new('/dev/null')) }

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
    context 'when download exceptions occur when ignore_errors is true' do
      let(:files) { %w[package1 package2 package3] }
      let(:checksum_type) { 'SHA256' }
      let(:file_entry_class) { Struct.new(:location, :checksum_type, :checksum, :type) }
      let(:queue) do
        files.map do |file|
          file_entry_class.new(
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
        downloader.download_multi(queue, ignore_errors: true)
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

    describe 'when download exceptions occur when ignore_errors is false' do
      let(:files) { %w[package1 package2 package3] }
      let(:checksum_type) { 'SHA256' }

      before do
        files.each do |file|
          stub_request(:get, "http://example.com/#{file}").with(headers: headers)
            .to_return(
              status: 404,
              body: lambda do |_|
                # This is a hack to inject something into the queue
                # It seems like WebMock doesn't populate it the same way as it normally would be populated.
                downloader.instance_variable_get(:@hydra).multi.easy_handles << Ethon::Easy.new(url: 'www.example.com')
                'dummy'
              end,
              headers: {}
            )
        end
      end

      it 'raises an exception' do
        expect do
          downloader.download_multi(files, ignore_errors: false)
        end.to raise_error('package1 - HTTP request failed with code 404')
      end

      it 'cleans up the queue of downloads' do
        expect do
          downloader.concurrency = 1
          downloader.download_multi(files, ignore_errors: false)
        end.to raise_error('package1 - HTTP request failed with code 404')

        expect(downloader.instance_variable_get(:@hydra).multi.easy_handles).to eq([])
        expect(downloader.instance_variable_get(:@queue)).to eq([])
      end
    end
  end
end
