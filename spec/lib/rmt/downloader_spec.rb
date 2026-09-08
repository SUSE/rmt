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

  let(:debug_request_error_regex) { /Request URL:.*Response HTTP status code:.*Response body:.*Response headers:.*curl return code:.*curl return message:/m }

  after do
    FileUtils.remove_entry(repository_dir)
    FileUtils.remove_entry(cache_dir) if cache_dir
  end

  def stub_logger(*methods)
    methods.each { |m| allow_any_instance_of(RMT::Logger).to receive(m) }
  end

  describe '#download over http://' do
    context 'when HTTP code is not 200' do
      before do
        allow_any_instance_of(RMT::Logger).to receive(:debug).with(/HTTP request/)
        stub_request(:get, 'http://example.com/repomd.xml')
          .with(headers: headers)
          .to_return(status: 404, body: '', headers: {})
      end

      it 'raises an exception' do
        expect_any_instance_of(RMT::Logger).to receive(:debug)
          .with(debug_request_error_regex).once
        expect { downloader.download_multi([repomd_xml_file]) }.to raise_error(
          RMT::Downloader::Exception,
          "http://example.com/repomd.xml - request failed with HTTP status code 404, return code ''"
        )
      end
    end

    context 'when processing response by Typhoeus failed' do
      before do
        allow_any_instance_of(RMT::Logger).to receive(:debug).with(/HTTP request/)
        allow(downloader).to receive(:cache_head_request).and_return(nil)
        stub_request(:get, 'http://example.com/repomd.xml')
          .with(headers: headers)
          .to_return(status: 200, body: 'Ok', headers: {})
      end

      it 'raises an exception' do
        expect_any_instance_of(RMT::Logger).to receive(:debug)
          .with(debug_request_error_regex).once

        allow(downloader).to receive(:invalid_response?).and_return(true)

        expect { downloader.download_multi([repomd_xml_file]) }.to raise_error(
          RMT::Downloader::Exception,
          %r{http://example\.com/repomd\.xml - request failed with HTTP status code 200}
        )
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
          expect { downloader.download_multi([repomd_xml_file]) }
            .to raise_error(RMT::ChecksumVerifier::Exception, 'Unknown hash function CHUNKYBACON42')
        end
      end

      context 'and checksum is wrong' do
        let(:expected_checksum_type) { 'SHA256' }
        let(:expected_checksum) { '0xDEADBEEF' }

        it 'raises an exception' do
          expect { downloader.download_multi([repomd_xml_file]) }
            .to raise_error(RMT::Downloader::Exception, 'Checksum doesn\'t match')
        end
      end

      context 'and checksum is correct' do
        before { downloader.download_multi([repomd_xml_file]) }

        let(:filename) { repomd_xml_file.local_path }

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
          downloader.download_multi([repomd_xml_file])

          expect(DownloadedFile.where("local_path like '%.xml'").count).to eq(0)
        end

        it 'tracks .rpm files' do
          downloader.download_multi([rpm_package_file])

          expect(DownloadedFile.where("local_path like '%.rpm'").count).to eq(1)
        end

        it 'tracks .drpm files' do
          downloader.download_multi([drpm_package_file])

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
        downloader.download_multi([repomd_xml_file])
      end

      context 'and checksum is correct' do
        let(:filename) { repomd_xml_file.local_path }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end

      context 'and checksum type is SHA and it is is correct' do
        let(:expected_checksum_type) { 'sha' }
        let(:expected_checksum) { Digest.const_get('SHA1').hexdigest(content) }
        let(:filename) { repomd_xml_file.local_path }

        it('has correct content') { expect(File.read(filename)).to eq(content) }
      end
    end

    describe '#download with cacheable file' do
      let(:cache_dir) { Dir.mktmpdir }
      let(:repository_dir) { Dir.mktmpdir }
      let(:time) { Time.utc(2018, 1, 1, 10, 10, 0) }
      let(:downloaded_file) do
        downloader.download_multi([repomd_xml_file])
        repomd_xml_file
      end
      let(:cached_content) { 'cached_content' }
      let(:fresh_content) { 'fresh_content' }

      context 'a file exists in cache and not modified' do
        before do
          File.write(repomd_xml_file.cache_path, cached_content)
          File.utime(time, time, repomd_xml_file.cache_path)
          stub_request(:head, 'http://example.com/repomd.xml')
            .with(headers: headers)
            .to_return(status: 200, headers: { 'Last-Modified': last_modified_header })
        end

        let(:last_modified_header) { 'Mon, 01 Jan 2018 10:10:00 GMT' }

        it('has correct content') { expect(File.read(downloaded_file.local_path)).to eq(cached_content) }
      end

      context 'a file exists in cache and is modified' do
        before do
          File.write(repomd_xml_file.cache_path, cached_content)
          File.utime(time, time, repomd_xml_file.cache_path)
          stub_request(:head, 'http://example.com/repomd.xml')
            .with(headers: headers)
            .to_return(status: 200, headers: { 'Last-Modified': last_modified_header })
          stub_request(:get, 'http://example.com/repomd.xml')
            .with(headers: headers)
            .to_return(status: 200, body: fresh_content, headers: {})
        end

        let(:last_modified_header) { 'Tue, 02 Jan 2018 10:10:00 GMT' }

        it('has correct content') { expect(File.read(downloaded_file.local_path)).to eq(fresh_content) }
      end

      context "a file exists in cache and its mtime is greater than 'Last-Modified' time" do
        before do
          File.write(repomd_xml_file.cache_path, cached_content)
          File.utime(time, time, repomd_xml_file.cache_path)
          stub_request(:head, 'http://example.com/repomd.xml')
            .with(headers: headers)
            .to_return(status: 200, headers: { 'Last-Modified': last_modified_header })
          stub_request(:get, 'http://example.com/repomd.xml')
            .with(headers: headers)
            .to_return(status: 200, body: fresh_content, headers: {})
        end

        let(:last_modified_header) { 'Sun, 31 Dec 2017 10:10:00 GMT' }

        it('has correct content') { expect(File.read(downloaded_file.local_path)).to eq(fresh_content) }
      end

      context 'a file exists in cache but the HEAD request fails' do
        before do
          File.write(repomd_xml_file.cache_path, cached_content)
          File.utime(time, time, repomd_xml_file.cache_path)
          stub_request(:head, 'http://example.com/repomd.xml')
            .with(headers: headers)
            .to_return(status: 404)
        end

        it 'raises an error' do
          expect { downloaded_file }.to raise_error(
            RMT::Downloader::Exception,
            "http://example.com/repomd.xml - request failed with HTTP status code 404, return code ''"
          )
        end
      end

      context 'when cache is invalid but local path exists' do
        let(:cache_dir) { Dir.mktmpdir }
        let(:file) do
          RMT::Mirror::FileReference.new(
            relative_path: 'test.rpm',
            base_url: repository_url,
            base_dir: repository_dir,
            cache_dir: cache_dir
          ).tap do |f|
            f.checksum = Digest::SHA256.hexdigest('fresh_content')
            f.checksum_type = 'SHA256'
          end
        end

        before do
          File.write(file.cache_path, 'stale_content')
          File.utime(Time.utc(2023, 1, 1), Time.utc(2023, 1, 1), file.cache_path)
          file.instance_variable_set(:@cache_timestamp, Time.utc(2023, 1, 1))
        end

        it 're-downloads instead of using stale cache' do
          stub_request(:head, 'http://example.com/test.rpm')
            .to_return(status: 200, headers: { 'Last-Modified' => 'Mon, 01 Jan 2024 00:00:00 GMT' })
          stub_request(:get, 'http://example.com/test.rpm')
            .to_return(status: 200, body: 'fresh_content', headers: {})

          downloader.download_multi([file])
          expect(File.read(file.local_path)).to eq('fresh_content')
          expect(File.read(file.local_path)).not_to eq('stale_content')
        end
      end

      context "a file doesn't exist in cache" do
        let(:another_file) do
          RMT::Mirror::FileReference.new(
            relative_path: 'another_file.xml',
            base_url: repository_url,
            base_dir: repository_dir,
            cache_dir: nil
          ).tap do |file|
            file.checksum = expected_checksum
            file.checksum_type = expected_checksum_type
          end
        end
        let(:downloaded_file) do
          downloader.download_multi([another_file])
          another_file.local_path
        end

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
    subject(:download) { downloader.download_multi([repomd_xml_file]) }

    let(:repository_dir) { Dir.mktmpdir }
    let(:repository_url_local_path) { File.expand_path(file_fixture('dummy_repo/')) + '/' }
    let(:repository_url) { URI.join('file://', repository_url_local_path) }
    let(:downloader) { described_class.new(logger: RMT::Logger.new('/dev/null')) }
    let(:repomd_xml_file) do
      RMT::Mirror::FileReference.new(
        relative_path: 'repodata/repomd.xml',
        base_url: repository_url,
        base_dir: repository_dir,
        cache_dir: repository_url_local_path
      )
    end

    before do
      stub_request(:head, /#{repository_url_local_path}/)
        .to_raise('should not make HEAD requests')
    end

    it 'saves the file when it exists' do
      download
      expect(File.size(repomd_xml_file.local_path)).to eq(File.size(file_fixture('dummy_repo/repodata/repomd.xml')))
    end

    context "when file doesn't exist" do
      let(:repository_url) { 'file://' + File.expand_path(file_fixture('.')) + '/non_existent/' }

      it 'raises and exception' do
        expect { downloader.download_multi([repomd_xml_file]) }
          .to raise_error { |error|
                expect(error).to be_a(RMT::Downloader::Exception)
                expect(error.message).to match(%r{/repodata/repomd.xml - File does not exist})
                expect(error.http_code).to eq(404)
              }
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
          base_dir: repository_dir,
          cache_dir: cache_dir
        ).tap do |file_ref|
          file_ref.checksum = Digest.const_get(checksum_type).hexdigest(file)
          file_ref.checksum_type = checksum_type
          file_ref.type = :rpm
        end
      end
    end

    context 'when download exceptions occur when ignore_errors is true' do
      before do
        allow_any_instance_of(described_class).to receive(:cache_head_request).and_return(nil)
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
            .to_return(status: 404, body: 'dummy', headers: {})
        end
      end

      it 'raises an exception' do
        expect do
          downloader.download_multi(queue.dup, ignore_errors: false)
        end.to raise_error("http://example.com/package1 - request failed with HTTP status code 404, return code ''")
      end

      it 'cleans up easy handles on error' do
        expect do
          downloader.concurrency = 1
          downloader.download_multi(queue.dup, ignore_errors: false)
        end.to raise_error("http://example.com/package1 - request failed with HTTP status code 404, return code ''")

        expect(downloader.instance_variable_get(:@hydra).multi.easy_handles).to eq([])
      end

      it 'deletes easy handles during error cleanup' do
        expect do
          downloader.download_multi(queue.dup, ignore_errors: false)
        end.to raise_error("http://example.com/package1 - request failed with HTTP status code 404, return code ''")
        expect(downloader.instance_variable_get(:@hydra).multi.easy_handles).to eq([])
      end

      it 'raises using failed_downloads branch when checksum fails' do
        failing_file = RMT::Mirror::FileReference.new(
          relative_path: 'bad-package.rpm',
          base_url: repository_url,
          base_dir: repository_dir,
          cache_dir: nil
        ).tap do |f|
          f.checksum = 'invalid'
          f.checksum_type = 'SHA256'
        end

        stub_request(:get, 'http://example.com/bad-package.rpm')
          .to_return(status: 200, body: 'dummy content', headers: {})

        expect do
          downloader.download_multi([failing_file], ignore_errors: false)
        end.to raise_error(RMT::Downloader::Exception, /Checksum/)
      end
    end

    context 'when there are cached files' do
      let(:cache_dir) { Dir.mktmpdir }

      context 'when a HEAD request fails and the ignore_errors = false' do
        before do
          queue.each do |file|
            FileUtils.touch(file.cache_path)
            stub_request(:head, file.remote_path.to_s).with(headers: headers)
              .to_return(status: 404, body: 'Not Found', headers: {})
          end
        end

        it 'raises an error' do
          expect { downloader.download_multi(queue.dup, ignore_errors: false) }
            .to raise_error(
              RMT::Downloader::Exception,
              %r{http://example.com/package[1-3] - request failed with HTTP status code 404, return code ''}
            )
        end
      end

      context 'when a HEAD request fails and the ignore_errors = true' do
        let(:queue) do
          files.map do |file|
            RMT::Mirror::FileReference.new(
              relative_path: file,
              base_url: repository_url,
              base_dir: repository_dir,
              cache_dir: cache_dir
            )
          end
        end

        before do
          queue.each do |file|
            FileUtils.touch(file.cache_path)
            stub_request(:head, file.remote_path.to_s).with(headers: headers)
              .to_return(status: 404, body: 'Not Found', headers: {})
          end
        end

        it 'returns a list of failed downloads' do
          failed_downloads = downloader.download_multi(queue.dup, ignore_errors: true)
          expect(failed_downloads).to match_array(queue.map(&:local_path))
        end
      end
    end
  end


  describe '#handle_response' do
    context 'when retries exhaust on non-404 failure' do
      let(:file) do
        RMT::Mirror::FileReference.new(
          relative_path: 'test.rpm',
          base_url: repository_url,
          base_dir: repository_dir,
          cache_dir: nil
        ).tap do |f|
          f.checksum = 'abc123'
          f.checksum_type = 'SHA256'
        end
      end

      it 'raises an exception' do
        stub_request(:get, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 500, body: 'Internal Server Error', headers: {})

        stub_logger(:warn, :debug)

        expect { downloader.download_multi([file]) }.to raise_error(RMT::Downloader::Exception)
      end
    end

    context 'when request succeeds after retries' do
      let(:file) do
        RMT::Mirror::FileReference.new(
          relative_path: 'test.rpm',
          base_url: repository_url,
          base_dir: repository_dir,
          cache_dir: nil
        ).tap do |f|
          f.checksum = Digest::SHA256.hexdigest('success_content')
          f.checksum_type = 'SHA256'
        end
      end

      it 'downloads successfully' do
        stub_request(:get, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 500, body: 'Internal Server Error', headers: {})
          .times(2)

        stub_request(:get, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 200, body: 'success_content', headers: {})

        stub_logger(:warn, :debug)

        downloader.download_multi([file])

        expect(File.read(file.local_path)).to eq('success_content')
      end
    end

    context 'with cache failure and 404' do
      let(:cache_dir) { Dir.mktmpdir }
      let(:file_a) do
        RMT::Mirror::FileReference.new(
          relative_path: 'a.rpm',
          base_url: repository_url,
          base_dir: repository_dir,
          cache_dir: cache_dir
        ).tap do |f|
          f.checksum = 'aaa'
          f.checksum_type = 'SHA256'
        end
      end
      let(:file_b) do
        RMT::Mirror::FileReference.new(
          relative_path: 'b.rpm',
          base_url: repository_url,
          base_dir: repository_dir,
          cache_dir: cache_dir
        ).tap do |f|
          f.checksum = 'bbb'
          f.checksum_type = 'SHA256'
        end
      end

      it 'adds file to failed_downloads when retries exhausted and ignore_errors is true with prior cache failure' do
        FileUtils.touch(file_a.cache_path)
        File.utime(Time.utc(2024, 1, 1), Time.utc(2024, 1, 1), file_a.cache_path)
        stub_request(:head, 'http://example.com/a.rpm').with(headers: headers)
          .to_return(status: 200, headers: { 'Last-Modified' => 'Tue, 01 Jan 2024 00:00:00 GMT' })
        stub_request(:head, 'http://example.com/b.rpm').with(headers: headers)
          .to_return(status: 200, headers: { 'Last-Modified' => 'Tue, 01 Jan 2024 00:00:00 GMT' })
        allow_any_instance_of(described_class).to receive(:copy_from_cache)
          .and_raise(RMT::Downloader::Exception.new('copy failed'))
        stub_request(:get, 'http://example.com/b.rpm').with(headers: headers)
          .to_return(status: 404, body: 'Not Found', headers: {})
        stub_logger(:warn, :debug)
        result = downloader.download_multi([file_a, file_b], ignore_errors: true)
        expect(result).to include(file_b)
      end
    end
  end

  describe '#finalize_download' do
    context 'with Last-Modified header' do
      let(:file) do
        RMT::Mirror::FileReference.new(
          relative_path: 'test.rpm',
          base_url: repository_url,
          base_dir: repository_dir,
          cache_dir: nil
        ).tap do |f|
          f.checksum = Digest::SHA256.hexdigest('header_content')
          f.checksum_type = 'SHA256'
        end
      end

      it 'sets file timestamps from Last-Modified header' do
        stub_request(:get, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 200, body: 'header_content', headers: { 'Last-Modified' => 'Mon, 01 Jan 2024 12:00:00 GMT' })

        stub_logger(:debug, :info)

        downloader.download_multi([file])

        expect(File.read(file.local_path)).to eq('header_content')
        mtime = File.mtime(file.local_path).utc
        expect(mtime.year).to eq(2024)
        expect(mtime.month).to eq(1)
        expect(mtime.day).to eq(1)
      end
    end

    context 'without Last-Modified header' do
      let(:file) do
        RMT::Mirror::FileReference.new(
          relative_path: 'test.rpm',
          base_url: repository_url,
          base_dir: repository_dir,
          cache_dir: nil
        ).tap do |f|
          f.checksum = Digest::SHA256.hexdigest('no_header_content')
          f.checksum_type = 'SHA256'
        end
      end

      it 'uses current time when no Last-Modified header is provided' do
        stub_request(:get, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 200, body: 'no_header_content', headers: { 'Content-Type' => 'application/x-rpm' })

        stub_logger(:debug, :info)

        downloader.download_multi([file])

        expect(File.read(file.local_path)).to eq('no_header_content')
      end
    end

    context 'on finalization error' do
      let(:file) do
        RMT::Mirror::FileReference.new(
          relative_path: 'test.rpm',
          base_url: repository_url,
          base_dir: repository_dir,
          cache_dir: nil
        ).tap do |f|
          f.checksum = 'invalid'
          f.checksum_type = 'SHA256'
        end
      end

      it 'cleans up temp file' do
        stub_request(:get, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 200, body: 'dummy content', headers: {})

        expect { downloader.download_multi([file]) }.to raise_error(RMT::Downloader::Exception)
      end
    end
  end

  describe '#handle_cache_copy rescue' do
    let(:cache_dir) { Dir.mktmpdir }
    let(:file) do
      RMT::Mirror::FileReference.new(
        relative_path: 'test.rpm',
        base_url: repository_url,
        base_dir: repository_dir,
        cache_dir: cache_dir
      ).tap do |f|
        f.checksum = 'abc'
        f.checksum_type = 'SHA256'
      end
    end

    before do
      FileUtils.touch(file.cache_path)
      File.utime(Time.utc(2024, 1, 1), Time.utc(2024, 1, 1), file.cache_path)
    end

    context 'with ignore_errors=true' do
      it 'adds to failed_files when copy_from_cache raises' do
        stub_request(:head, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 200, headers: { 'Last-Modified' => 'Tue, 01 Jan 2024 00:00:00 GMT' })
        allow_any_instance_of(described_class).to receive(:copy_from_cache).and_raise(
          RMT::Downloader::Exception.new('copy failed')
        )

        result = downloader.download_multi([file], ignore_errors: true)
        expect(result).to include(file.local_path)
      end
    end

    context 'with ignore_errors=false' do
      it 'raises exception when copy_from_cache fails' do
        stub_request(:head, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 200, headers: { 'Last-Modified' => 'Tue, 01 Jan 2024 00:00:00 GMT' })
        allow_any_instance_of(described_class).to receive(:copy_from_cache).and_raise(
          RMT::Downloader::Exception.new('copy failed')
        )

        expect { downloader.download_multi([file], ignore_errors: false) }
          .to raise_error(RMT::Downloader::Exception, /copy failed/)
      end
    end
  end

  describe '#handle_cache_head_response' do
    let(:cache_dir) { Dir.mktmpdir }
    let(:cached_content) { 'cached_content' }
    let(:file) do
      RMT::Mirror::FileReference.new(
        relative_path: 'test.rpm',
        base_url: repository_url,
        base_dir: repository_dir,
        cache_dir: cache_dir
      )
    end

    before do
      File.write(file.cache_path, cached_content)
      File.utime(Time.utc(2024, 1, 1), Time.utc(2024, 1, 1), file.cache_path)
    end

    context 'when response is valid' do
      it 'returns early' do
        request = instance_double(RMT::HttpRequest)
        response = instance_double(Typhoeus::Response, code: 200, return_code: :ok)
        allow(request).to receive(:retries=)
        allow(request).to receive(:retries).and_return(4)
        allow(request).to receive(:run)
        expect(request).not_to receive(:retries=)
        downloader.send(:handle_cache_head_response, response, request)
      end
    end

    context 'when retries is 0' do
      it 'does not retry' do
        request = instance_double(RMT::HttpRequest)
        response = instance_double(Typhoeus::Response, code: 503, return_code: :error, effective_url: 'http://example.com/test.rpm')
        allow(request).to receive(:retries=)
        allow(request).to receive(:retries).and_return(0)
        allow(request).to receive(:run)
        expect(request).not_to receive(:retries=)
        expect(request).not_to receive(:run)
        downloader.send(:handle_cache_head_response, response, request)
      end
    end

    context 'when HEAD fails then succeeds' do
      it 'succeeds on retry' do
        stub_request(:head, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 503, body: 'Service Unavailable', headers: {})
          .times(2)

        stub_request(:head, 'http://example.com/test.rpm')
          .with(headers: headers)
          .to_return(status: 200, headers: { 'Last-Modified' => 'Mon, 01 Jan 2024 00:00:00 GMT' })

        stub_logger(:warn, :debug)

        downloader.download_multi([file])
        expect(File.read(file.local_path)).to eq(cached_content)
      end
    end
  end

  describe '#valid_cached_file? exception path' do
    let(:invalid_response) do
      instance_double(Typhoeus::Response,
                      code: 503, body: 'Service Unavailable', effective_url: 'http://example.com/test.rpm',
                      return_code: :ok, return_message: '',
                      response_headers: '',
                      headers: { 'Last-Modified' => 'Mon, 01 Jan 2024 00:00:00 GMT' })
    end

    let(:file) do
      RMT::Mirror::FileReference.new(
        relative_path: 'test.rpm',
        base_url: repository_url,
        base_dir: repository_dir,
        cache_dir: Dir.mktmpdir
      ).tap do |f|
        allow(f).to receive(:cache_timestamp).and_return(Time.utc(2024, 1, 1))
        FileUtils.touch(f.cache_path)
      end
    end

    it 'raises an exception when response is invalid' do
      expect { downloader.send(:valid_cached_file?, file, invalid_response) }
        .to raise_error(RMT::Downloader::Exception, /request failed with HTTP status code 503/)
    end
  end

  describe '#invalid_response?' do
    context 'with nil response' do
      it 'returns true' do
        expect(downloader.send(:invalid_response?, nil)).to be true
      end
    end

    context 'with code 0 and :ok return_code' do
      it 'returns false' do
        response = instance_double(Typhoeus::Response, code: 0, return_code: :ok)
        expect(downloader.send(:invalid_response?, response)).to be false
      end
    end
  end

  describe '#raise_request_error' do
    context 'with nil response' do
      it 'raises with generic message' do
        expect { downloader.send(:raise_request_error, 'http://example.com/test.rpm', nil) }
          .to raise_error(RMT::Downloader::Exception, /test\.rpm - request failed/)
      end
    end

    context 'with valid response' do
      let(:response) do
        instance_double(Typhoeus::Response,
                        effective_url: 'http://example.com/test.rpm',
                        code: 503,
                        body: 'Service Unavailable',
                        response_headers: 'Content-Type: text/html',
                        return_code: :ok,
                        return_message: '')
      end

      it 'raises an exception with detailed error message' do
        expect { downloader.send(:raise_request_error, 'http://example.com/test.rpm', response) }
          .to raise_error(RMT::Downloader::Exception, /test\.rpm - request failed with HTTP status code 503/)
      end
    end
  end
end
