require 'rails_helper'
require 'webmock/rspec'

RSpec.describe RMT::Downloader do
  let(:repository_url) { 'http://example.com' }
  let(:repository_dir) { Dir.mktmpdir }
  let(:cache_dir) { nil }
  let(:headers) { { 'User-Agent' => "RMT/#{RMT::VERSION}" } }
  let(:track_files) { false }
  let(:downloader) do
    described_class.new(logger: RMT::Logger.new('/dev/null'),
                        track_files: track_files)
  end

  let(:expected_checksum) { nil }
  let(:expected_checksum_type) { nil }
  let(:repomd_xml_file) do
    RMT::Mirror::FileReference.new(
      relative_path: 'repomd.xml',
      base_url: repository_url,
      base_dir: repository_dir,
      cache_dir: cache_dir
    ).tap do |file|
      file.checksum = expected_checksum
      file.checksum_type = expected_checksum_type
    end
  end

  after do
    FileUtils.remove_entry(repository_dir)
    FileUtils.remove_entry(cache_dir) if cache_dir
  end

  describe '#download over http://' do
    context 'when HTTP code is not 200' do
      before do
        stub_request(:get, 'http://example.com/repomd.xml')
          .with(headers: headers)
          .to_return(status: 404, body: '', headers: {})
      end

      it 'raises an exception' do
        expect { downloader.download(repomd_xml_file) }
          .to raise_error(RMT::Downloader::Exception, 'http://example.com/repomd.xml - HTTP request failed with code 404')
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

        expect { downloader.download(repomd_xml_file) }
          .to raise_error(RMT::Downloader::Exception, 'http://example.com/repomd.xml - return code error')
      end
    end

    context 'when HTTP code is 200' do
      let(:content) { 'test' }
      let(:expected_checksum_type) { 'SHA256' }
      let(:expected_checksum) { Digest.const_get(expected_checksum_type).hexdigest(content) }

      before do
        stub_request(:get, 'http://example.com/repomd.xml')
          .with(headers: headers)
          .to_return(status: 200, body: content, headers: {})
      end

      context 'and hash function is unknown' do
        let(:expected_checksum_type) { 'CHUNKYBACON42' }
        let(:expected_checksum) { '0xDEADBEEF' }

        it 'raises an exception' do
          expect { downloader.download(repomd_xml_file) }
            .to raise_error(RMT::ChecksumVerifier::Exception, 'Unknown hash function CHUNKYBACON42')
        end
      end

      context 'and checksum is wrong' do
        let(:expected_checksum_type) { 'SHA256' }
        let(:expected_checksum) { '0xDEADBEEF' }

        it 'raises an exception' do
          expect { downloader.download(repomd_xml_file) }
            .to raise_error(RMT::Downloader::Exception, 'Checksum doesn\'t match')
        end
      end

      context 'and checksum is correct' do
        let(:filename) { downloader.download(repomd_xml_file) }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end

      context 'tracking files' do
        let(:track_files) { true }
        let(:rpm_package_content) { 'rpm package' }
        let(:rpm_package_file) do
          RMT::Mirror::FileReference.new(
            relative_path: 'package.rpm',
            base_url: repository_url,
            base_dir: repository_dir
          ).tap do |file|
            file.checksum = Digest.const_get('SHA256').hexdigest(rpm_package_content)
            file.checksum_type = 'SHA256'
          end
        end
        let(:drpm_package_content) { 'drpm package' }
        let(:drpm_package_file) do
          RMT::Mirror::FileReference.new(
            relative_path: 'package.drpm',
            base_url: repository_url,
            base_dir: repository_dir
          ).tap do |file|
            file.checksum = Digest.const_get('SHA256').hexdigest(drpm_package_content)
            file.checksum_type = 'SHA256'
          end
        end

        before do
          stub_request(:get, 'http://example.com/package.rpm')
            .with(headers: headers)
            .to_return(status: 200, body: rpm_package_content, headers: {})

          stub_request(:get, 'http://example.com/package.drpm')
            .with(headers: headers)
            .to_return(status: 200, body: drpm_package_content, headers: {})
        end


        it 'does not track .xml files' do
          downloader.download(repomd_xml_file)

          expect(DownloadedFile.where("local_path like '%.xml'").count).to eq(0)
        end

        it 'tracks .rpm files' do
          downloader.download(rpm_package_file)

          expect(DownloadedFile.where("local_path like '%.rpm'").count).to eq(1)
        end

        it 'tracks .drpm files' do
          downloader.download(drpm_package_file)

          expect(DownloadedFile.where("local_path like '%.drpm'").count).to eq(1)
        end
      end
    end

    context 'with auth_token' do
      let(:downloader) do
        described_class.new(
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
        let(:filename) { downloader.download(repomd_xml_file) }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end

      context 'and checksum type is SHA and it is is correct' do
        let(:expected_checksum_type) { 'sha' }
        let(:expected_checksum) { Digest.const_get('SHA1').hexdigest(content) }
        let(:filename) { downloader.download(repomd_xml_file) }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end
    end

    describe '#download with If-Modified-Since' do
      let(:cache_dir) { Dir.mktmpdir }
      let(:repository_dir) { Dir.mktmpdir }
      let(:time) { Time.utc(2018, 1, 1, 10, 10, 0) }
      let(:if_modified_headers) do
        {
          'User-Agent' => "RMT/#{RMT::VERSION}",
          'If-Modified-Since' => 'Mon, 01 Jan 2018 10:10:00 GMT'
        }
      end
      let(:downloaded_file) { downloader.download(repomd_xml_file) }
      let(:cached_content) { 'cached_content' }
      let(:fresh_content) { 'fresh_content' }

      context 'a file exists in cache and not modified' do
        before do
          File.open(repomd_xml_file.cache_path, 'w') { |file| file.write(cached_content) }
          File.utime(time, time, repomd_xml_file.cache_path)
          stub_request(:get, 'http://example.com/repomd.xml')
              .with(headers: if_modified_headers)
              .to_return(status: 304, body: '', headers: {})
        end

        it('has correct content') { expect(File.read(downloaded_file)).to eq(cached_content) }
      end

      context 'a file exists in cache and is modified' do
        before do
          File.open(repomd_xml_file.cache_path, 'w') { |file| file.write(cached_content) }
          File.utime(time, time, repomd_xml_file.cache_path)
          stub_request(:get, 'http://example.com/repomd.xml')
              .with(headers: if_modified_headers)
              .to_return(status: 200, body: fresh_content, headers: {})
        end

        it('has correct content') { expect(File.read(downloaded_file)).to eq(fresh_content) }
      end

      context "a file doesn't exist in cache" do
        let(:another_file) do
          RMT::Mirror::FileReference.new(
            relative_path: 'another_file.xml',
            base_url: repository_url,
            base_dir: repository_dir,
            cache_dir: cache_dir
          ).tap do |file|
            file.checksum = expected_checksum
            file.checksum_type = expected_checksum_type
          end
        end
        let(:downloaded_file) { downloader.download(another_file) }

        before do
          stub_request(:get, 'http://example.com/another_file.xml')
              .with(headers: headers)
              .to_return(status: 200, body: fresh_content, headers: {})
        end

        it('has correct content') { expect(File.read(downloaded_file)).to eq(fresh_content) }
      end
    end
  end

  describe '#download over file://' do
    subject(:download) { downloader.download(repomd_xml_file) }

    let(:repository_dir) { Dir.mktmpdir }
    let(:repository_url) { 'file://' + File.expand_path(file_fixture('dummy_repo/')) + '/' }
    let(:downloader) { described_class.new(logger: RMT::Logger.new('/dev/null')) }
    let(:repomd_xml_file) do
      RMT::Mirror::FileReference.new(
        relative_path: 'repodata/repomd.xml',
        base_url: repository_url,
        base_dir: repository_dir
      )
    end

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
      let(:repository_url) { 'file://' + File.expand_path(file_fixture('.')) + '/non_existent/' }

      it 'raises and exception' do
        expect { downloader.download(repomd_xml_file) }
          .to raise_error(
            RMT::Downloader::Exception,
            %r{/repodata/repomd.xml - File does not exist}
          )
      end
    end
  end

  describe '#download_multi' do
    let(:files) { %w[package1 package2 package3] }
    let(:checksum_type) { 'SHA256' }
    let(:queue) do
      files.map do |file|
        RMT::Mirror::FileReference.new(
          relative_path: file,
          base_url: repository_url,
          base_dir: repository_dir
        ).tap do |file_ref|
          file_ref.checksum = Digest.const_get(checksum_type).hexdigest(file)
          file_ref.checksum_type = checksum_type
          file_ref.type = :rpm
        end
      end
    end

    context 'when download exceptions occur when ignore_errors is true' do
      before do
        files.each do |file|
          stub_request(:get, "http://example.com/#{file}").with(headers: headers)
            .to_return(status: 404, body: file, headers: {})
        end
      end

      it 'requested all files' do
        downloader.download_multi(queue.dup, ignore_errors: true)

        files.each do |file|
          expect(WebMock).to(
            have_requested(:get, "http://example.com/#{file}").with(headers: headers)
          )
        end
      end

      it 'but no files were actually saved' do
        downloader.download_multi(queue.dup, ignore_errors: true)

        queue.each do |file|
          expect(File.exist?(file.local_path)).to eq(false)
        end
      end
    end

    context 'when download exceptions occur when ignore_errors is false' do
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
          downloader.download_multi(queue.dup, ignore_errors: false)
        end.to raise_error('http://example.com/package1 - HTTP request failed with code 404')
      end

      it 'cleans up the queue of downloads' do
        expect do
          downloader.concurrency = 1
          downloader.download_multi(queue.dup, ignore_errors: false)
        end.to raise_error('http://example.com/package1 - HTTP request failed with code 404')

        expect(downloader.instance_variable_get(:@hydra).multi.easy_handles).to eq([])
        expect(downloader.instance_variable_get(:@queue)).to eq([])
      end
    end
  end
end
