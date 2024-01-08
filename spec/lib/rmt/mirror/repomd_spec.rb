require 'rails_helper'

RSpec.describe RMT::Mirror::Repomd do
  subject(:repomd) { described_class.new(**repomd_configuration) }

  RSpec::Matchers.define :file_reference_containing_path do |expected|
    match do |actual|
      actual.local_path.include?(expected)
    end

    failure_message do |actual|
      "expected that file path #{actual.local_path} would contain #{expected}"
    end
  end

  let(:logger) { RMT::Logger.new('/dev/null') }


  let(:repository) do
    create :repository,
           name: 'SUSE Linux Enterprise Server 15 SP4',
           external_url: 'https://updates.suse.com/sample/repository/15.4/'
  end

  # Configuration for Debian mirroring instance
  let(:base_dir) { '/test/repository/base/path/' }
  let(:repomd_configuration) do
    {
      repository: repository,
      logger: logger,
      mirroring_base_dir: base_dir
    }
  end

  # Configuration for file reference to an arbitrary fixture
  let(:fixture) { 'repodata/repomd.xml' }
  let(:config) do
    {
      relative_path: fixture,
      base_dir: file_fixture('dummy_repo/'),
      base_url: 'https://updates.suse.com/sample/repository/15.4/'
    }
  end
  let(:repomd_ref) { RMT::Mirror::FileReference.new(**config) }

  describe '#mirror_implementation' do
    it 'mirrors the metadata'
    it 'mirrors the licenses'
    it 'mirrors the packages'
    it 'replaces license and metadata directories'
  end
  
  describe '#mirror_metadata' do
    let(:x_config) do
      {
        base_dir: base_dir,
        base_url: 'https://updates.suse.com/sample/repository/15.4/',
        cache_dir: repomd.repository_path
      }
    end

    before do
      described_class.send(:public, *described_class.protected_instance_methods)
      allow(repomd).to receive(:create_repository_path)
      allow(repomd).to receive(:temp).with(:metadata).and_return(base_dir)
    end

    let(:signature_file) { RMT::Mirror::FileReference.new(relative_path: 'repodata/repomd.xml.asc', **x_config) }
    let(:key_file) { RMT::Mirror::FileReference.new(relative_path: 'repodata/repomd.xml.key', **x_config) }
    let(:repomd_parser) { RepomdParser::RepomdXmlParser.new(repomd_ref.local_path) }

    it 'checks signature of the repomd file' do
      allow(repomd).to receive(:download_cached!).and_return(repomd_ref)
      allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_return([])
      allow(repomd).to receive(:enqueue)
      allow(repomd).to receive(:download_enqueued)
      expect(repomd).to receive(:check_signature).with(key_file: duck_type(:local_path), signature_file: duck_type(:local_path), metadata_file: duck_type(:local_path))
      repomd.mirror_metadata
    end

    it 'parses the repomd file' do
      allow(repomd).to receive(:download_cached!).and_return(repomd_ref)
      allow(repomd).to receive(:check_signature)
      expect(RepomdParser::RepomdXmlParser).to receive(:new).with(repomd_ref.local_path).and_return(repomd_parser)
      expect(repomd_parser).to receive(:parse).and_call_original
      expect(repomd).to receive(:enqueue).with(duck_type(:local_path)).exactly(4).times
      allow(repomd).to receive(:download_enqueued)
      metadatas = repomd.mirror_metadata
      expect(metadatas.count).to eq(4)
    end

    it 'downloads the metadata files' do
      allow(repomd).to receive(:download_cached!).and_return(repomd_ref)
      allow(repomd).to receive(:check_signature)
      allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_return([])
      allow(repomd).to receive(:enqueue)
      expect(repomd).to receive(:download_enqueued)
      repomd.mirror_metadata
    end

    it 'handles generic errors' do
      allow(repomd).to receive(:download_cached!).and_return(repomd_ref)
      allow(repomd).to receive(:check_signature)
      allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_raise(StandardError)
      expect { repomd.mirror_metadata }.to raise_exception(RMT::Mirror::Exception, /Error while mirroring/)
    end

  end

  xdescribe '#mirror' do
    around do |example|
      @tmp_dir = Dir.mktmpdir('rmt')
      example.run
      FileUtils.remove_entry(@tmp_dir)
    end

    before do
      allow_any_instance_of(RMT::GPG).to receive(:verify_signature)
    end

    after do
      Dir.glob(File.join(Dir.tmpdir, 'rmt_mirror_*', '**'))
        .each { |tmpdir| FileUtils.remove_entry(tmpdir, true) }
    end

    context 'without auth_token' do
      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_repo/',
          local_path: '/dummy_repo'
        }
      end

      let(:license_config) do
        {
          relative_path: "directory.yast",
          base_dir: file_fixture(''),
          base_url: 'https://updates.suse.de/SLES/'
        }
      end
      let(:directory_yast_ref) { RMT::Mirror::FileReference.new(**license_config) }

      before do
        allow(FileUtils).to receive(:mkpath) #.with(repomd.repository_path).and_return(nil)
        described_class.send(:public, *described_class.protected_instance_methods)
        allow_any_instance_of(RMT::Mirror::License).to receive(:licenses_available?).and_return(true)
        allow_any_instance_of(RMT::Mirror::License).to receive(:download_cached!).and_return(directory_yast_ref)
        expect_any_instance_of(RMT::Mirror::License).to receive(:download_enqueued)
        expect_any_instance_of(RMT::Mirror::License).to receive(:replace_directory)
        expect(repomd).to receive(:mirror_metadata)
        repomd.mirror
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end
    end

    xcontext 'importing local repo' do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: URI.join('file://', File.expand_path(file_fixture('dummy_repo'))).to_s + '/',
          local_path: Repository.make_local_path('dummy_repo/'),
          repo_name: 'dummy_repo'
        }
      end

      before do
        rmt_mirror.mirror(**mirror_params)
      end

      it 'copies rpm files' do
        expect(Dir.entries(File.join(@tmp_dir, 'dummy_repo'))).to match_array(Dir.entries(file_fixture('dummy_repo')))
      end

      it 'copies metadata' do
        expect(Dir.entries(File.join(@tmp_dir, 'dummy_repo/repodata'))).to match_array(Dir.entries(file_fixture('dummy_repo/repodata')))
      end
    end

    xcontext 'without auth_token and with source packages', vcr: { cassette_name: 'mirroring_with_src' } do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: logger,
          mirror_src: mirror_src
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_repo_with_src/',
          local_path: '/dummy_repo'
        }
      end

      before do
        rmt_mirror.mirror(**mirror_params)
      end

      context 'when mirror_src is false' do
        let(:mirror_src) { false }

        it 'downloads rpm files' do
          rpm_entries = Dir.glob(File.join(@tmp_dir, 'dummy_repo', '**', '*.rpm'))
          expect(rpm_entries.length).to eq(2)
        end

        it 'downloads drpm files' do
          rpm_entries = Dir.glob(File.join(@tmp_dir, 'dummy_repo', '**', '*.drpm'))
          expect(rpm_entries.length).to eq(1)
        end
      end

      context 'when mirror_src is true' do
        let(:mirror_src) { true }

        it 'downloads rpm files' do
          rpm_entries = Dir.glob(File.join(@tmp_dir, 'dummy_repo', '**', '*.rpm'))
          expect(rpm_entries.length).to eq(4)
        end

        it 'downloads drpm files' do
          rpm_entries = Dir.glob(File.join(@tmp_dir, 'dummy_repo', '**', '*.drpm'))
          expect(rpm_entries.length).to eq(1)
        end
      end
    end

    xcontext 'with auth_token', vcr: { cassette_name: 'mirroring_with_auth_token' } do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_repo/',
          local_path: '/dummy_repo',
          auth_token: 'repo_auth_token'
        }
      end

      before do
        expect(logger).to receive(:info).with(/Mirroring repository/).once
        expect(logger).to receive(:info).with('Repository metadata signatures are missing').once
        expect(logger).to receive(:info).with(/↓/).at_least(:once)
        rmt_mirror.mirror(**mirror_params)
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_repo')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end
    end

    xcontext 'product with license and signatures', vcr: { cassette_name: 'mirroring_product' } do
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      before do
        expect(logger).to receive(:info).with(/Mirroring repository/).once
        expect(logger).to receive(:info).with(/↓/).at_least(:once)
        rmt_mirror.mirror(**mirror_params)
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_product/product/')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'downloads drpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_product/product/')).select { |entry| entry =~ /\.drpm$/ }
        expect(rpm_entries.length).to eq(2)
      end

      it 'downloads repomd.xml signatures' do
        ['repomd.xml.key', 'repomd.xml.asc'].each do |file|
          expect(File.size(File.join(@tmp_dir, 'dummy_product/product/repodata/', file))).to be > 0
        end
      end

      it 'downloads product license' do
        ['directory.yast', 'license.txt', 'license.de.txt', 'license.ru.txt'].each do |file|
          expect(File.size(File.join(@tmp_dir, 'dummy_product/product.license/', file))).to be > 0
        end
      end
    end

    xcontext 'when an error occurs' do
      let(:mirroring_dir) { @tmp_dir }
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: mirroring_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      context 'when mirroring_base_dir is not writable' do
        let(:mirroring_dir) { '/non/existent/path' }

        it 'raises exception', vcr: { cassette_name: 'mirroring_product' } do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception)
        end
      end

      context "when can't create tmp dir", vcr: { cassette_name: 'mirroring_product' } do
        before { allow(Dir).to receive(:mktmpdir).and_raise('mktmpdir exception') }

        it 'handles the exception' do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception)
        end
      end

      context "when can't download metadata", vcr: { cassette_name: 'mirroring_product' } do
        before do
          allow_any_instance_of(RMT::Downloader).to receive(:download_multi).and_call_original
          expect_any_instance_of(RMT::Downloader)
            .to receive(:download_multi)
            .with([file_reference_containing_path('repodata/repomd.xml')])
            .and_raise(RMT::Downloader::Exception, "418 - I'm a teapot")
        end

        it 'handles RMT::Downloader::Exception' do
          expect { rmt_mirror.mirror(**mirror_params) }
            .to raise_error(RMT::Mirror::Exception, "Error while mirroring metadata: 418 - I'm a teapot")
        end
      end

      context "when there's no licenses to download", vcr: { cassette_name: 'mirroring' } do
        let(:rmt_mirror) do
          described_class.new(
            mirroring_base_dir: @tmp_dir,
            logger: logger,
            mirror_src: false
          )
        end

        let(:mirror_params) do
          {
            repository_url: 'http://localhost/dummy_repo/',
            local_path: '/dummy_product/product/'
          }
        end

        it 'does not error out' do
          expect { rmt_mirror.mirror(**mirror_params) }.not_to raise_error
        end

        it 'does not create a product.licenses directory' do
          rmt_mirror.mirror(**mirror_params)
          expect(Dir).not_to exist(File.join(@tmp_dir, 'dummy_product', 'product.license'))
        end

        it 'removes the temporary licenses directory' do
          rmt_mirror.mirror(**mirror_params)
          tmp_dir_glob = Dir.glob(File.join(Dir.tmpdir, 'rmt_mirror_*', '**'))
          expect(tmp_dir_glob.length).to eq(0)
        end
      end

      context "when can't download some of the license files" do
        before do
          allow_any_instance_of(RMT::Downloader).to receive(:download_multi).and_wrap_original do |klass, *args|
            raise RMT::Downloader::Exception.new('') if /license/.match?(args[0][0].local_path)

            klass.call(*args)
          end
        end

        it 'handles RMT::Downloader::Exception', vcr: { cassette_name: 'mirroring_product' } do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(RMT::Mirror::Exception, /Error while mirroring license files:/)
        end
      end

      context "when can't parse metadata", vcr: { cassette_name: 'mirroring_product' } do
        before { allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_raise('Parse error') }

        it 'removes the temporary metadata directory' do
          expect { rmt_mirror.mirror(**mirror_params) }
            .to raise_error(RMT::Mirror::Exception, 'Error while mirroring metadata: Parse error')

          tmp_dir_glob = Dir.glob(File.join(Dir.tmpdir, 'rmt_mirror_*', '**'))
          expect(tmp_dir_glob.length).to eq(0)
        end
      end

      context 'when Interrupt is raised', vcr: { cassette_name: 'mirroring_product' } do
        before { allow_any_instance_of(RepomdParser::RepomdXmlParser).to receive(:parse).and_raise(Interrupt.new) }

        it 'removes the temporary metadata directory' do
          expect { rmt_mirror.mirror(**mirror_params) }.to raise_error(Interrupt)

          tmp_dir_glob = Dir.glob(File.join(Dir.tmpdir, 'rmt_mirror_*', '**'))
          expect(tmp_dir_glob.length).to eq(0)
        end
      end

      context "when can't download data", vcr: { cassette_name: 'mirroring_product' } do
        it 'handles RMT::Downloader::Exception' do
          allow_any_instance_of(RMT::Downloader).to receive(:make_request).and_wrap_original do |klass, *args|
            # raise the exception only for the RPMs/DRPMs
            raise(RMT::Downloader::Exception, "418 - I'm a teapot") if /rpm$/.match?(args[0].local_path)

            klass.call(*args)
          end

          expect do
            rmt_mirror.mirror(**mirror_params)
          end.to raise_error(RMT::Mirror::Exception, 'Error while mirroring packages: Failed to download 6 files')
        end

        it 'handles RMT::ChecksumVerifier::Exception' do
          allow_any_instance_of(RMT::Downloader).to receive(:make_request).and_wrap_original do |klass, *args|
            # raise the exception only for the RPMs/DRPMs
            raise(RMT::ChecksumVerifier::Exception, "Checksum doesn't match") if /rpm$/.match?(args[0].local_path)

            klass.call(*args)
          end

          expect do
            rmt_mirror.mirror(**mirror_params)
          end.to raise_error(RMT::Mirror::Exception, 'Error while mirroring packages: Failed to download 6 files')
        end
      end
    end

    xcontext 'deduplication' do
      let(:rmt_source_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: RMT::Logger.new('/dev/null'),
          mirror_src: false
        )
      end

      let(:rmt_dedup_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: RMT::Logger.new('/dev/null'),
          mirror_src: false
        )
      end

      let(:rmt_dedup_airgap_mirror) do
        described_class.new(
          mirroring_base_dir: @tmp_dir,
          logger: RMT::Logger.new('/dev/null'),
          mirror_src: false,
          airgap_mode: true
        )
      end

      let(:mirror_params_source) do
        {
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      let(:mirror_params_dedup) do
        {
          repository_url: 'http://localhost/dummy_deduped_product/product/',
          local_path: '/dummy_deduped_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      let(:dedup_path) { File.join(@tmp_dir, 'dummy_deduped_product/product/') }
      let(:source_path) { File.join(@tmp_dir, 'dummy_product/product/') }

      shared_examples_for 'a deduplicated run' do |source_nlink, dedup_nlink, has_same_content|
        it 'downloads source rpm files' do
          rpm_entries = Dir.entries(File.join(source_path)).select { |entry| entry =~ /\.rpm$/ }
          expect(rpm_entries.length).to eq(4)
        end

        it 'deduplicates rpm files' do
          rpm_entries = Dir.entries(File.join(dedup_path)).select { |entry| entry =~ /\.rpm$/ }
          expect(rpm_entries.length).to eq(4)
        end

        it 'has correct content for deduplicated rpm files' do
          Dir.entries(File.join(dedup_path)).select { |entry| entry =~ /\.rpm$/ }.each do |file|
            if has_same_content
              expect(File.read(dedup_path + file)).to eq(File.read(source_path + file))
            else
              expect(File.read(dedup_path + file)).not_to eq(File.read(source_path + file))
            end
          end
        end

        it "source rpms have #{source_nlink} nlink" do
          Dir.entries(source_path).select { |entry| entry =~ /\.rpm$/ }.each do |file|
            expect(File.stat(source_path + file).nlink).to eq(source_nlink)
          end
        end

        it "dedup rpms have #{dedup_nlink} nlink" do
          Dir.entries(dedup_path).select { |entry| entry =~ /\.rpm$/ }.each do |file|
            expect(File.stat(dedup_path + file).nlink).to eq(dedup_nlink)
          end
        end

        it 'downloads source drpm files' do
          rpm_entries = Dir.entries(File.join(source_path)).select { |entry| entry =~ /\.drpm$/ }
          expect(rpm_entries.length).to eq(2)
        end

        it 'deduplicates drpm files' do
          rpm_entries = Dir.entries(File.join(dedup_path)).select { |entry| entry =~ /\.drpm$/ }
          expect(rpm_entries.length).to eq(2)
        end

        it 'has correct content for deduplicated drpm files' do
          Dir.entries(File.join(dedup_path)).select { |entry| entry =~ /\.drpm$/ }.each do |file|
            if has_same_content
              expect(File.read(dedup_path + file)).to eq(File.read(source_path + file))
            else
              expect(File.read(dedup_path + file)).not_to eq(File.read(source_path + file))
            end
          end
        end

        it "source drpms have #{source_nlink} nlink" do
          Dir.entries(source_path).select { |entry| entry =~ /\.drpm$/ }.each do |file|
            expect(File.stat(source_path + file).nlink).to eq(source_nlink)
          end
        end

        it "dedup drpms have #{dedup_nlink} nlink" do
          Dir.entries(dedup_path).select { |entry| entry =~ /\.drpm$/ }.each do |file|
            expect(File.stat(dedup_path + file).nlink).to eq(dedup_nlink)
          end
        end
      end

      context 'by copy' do
        before do
          deduplication_method(:copy)
          VCR.use_cassette 'mirroring_product_with_dedup' do
            rmt_source_mirror.mirror(**mirror_params_source)
            rmt_dedup_mirror.mirror(**mirror_params_dedup)
          end
        end

        it_behaves_like 'a deduplicated run', 1, 1, true
      end

      context 'by hardlink' do
        before do
          deduplication_method(:hardlink)
          VCR.use_cassette 'mirroring_product_with_dedup' do
            rmt_source_mirror.mirror(**mirror_params_source)
            rmt_dedup_mirror.mirror(**mirror_params_dedup)
          end
        end

        it_behaves_like 'a deduplicated run', 2, 2, true
      end

      context 'tracking downloaded files' do
        before do
          deduplication_method(:hardlink)
        end

        it 'tracks deduplicated files' do
          VCR.use_cassette 'mirroring_product_with_dedup' do
            rmt_source_mirror.mirror(**mirror_params_source)
            rmt_dedup_mirror.mirror(**mirror_params_dedup)
          end
          rpm_entries = Dir.entries(File.join(source_path)).select { |entry| entry =~ /\.rpm$/ }
          count = rpm_entries.inject(0) { |count, entry| count + DownloadedFile.where("local_path like '%#{entry}'").count }
          expect(count).to eq(8)
        end

        it 'does not track airgap deduplicated files' do
          VCR.use_cassette 'mirroring_product_with_dedup' do
            rmt_source_mirror.mirror(**mirror_params_source)
            rmt_dedup_airgap_mirror.mirror(**mirror_params_dedup)
          end
          rpm_entries = Dir.entries(File.join(source_path)).select { |entry| entry =~ /\.rpm$/ }
          count = rpm_entries.inject(0) { |count, entry| count + DownloadedFile.where("local_path like '%#{entry}'").count }
          expect(count).to eq(4)
        end
      end

      context 'by copy with corruption' do
        subject(:deduplicate_mirror) do
          VCR.use_cassette 'mirroring_product_with_dedup' do
            deduplication_method(:copy)
            rmt_dedup_mirror.mirror(**mirror_params_dedup)
          end
        end

        before do
          deduplication_method(:copy)
          VCR.use_cassette 'mirroring_product_with_dedup' do
            rmt_source_mirror.mirror(**mirror_params_source)
            Dir.entries(source_path).select { |entry| entry =~ /(\.drpm|\.rpm)$/ }.each do |filename|
              File.write(source_path + filename, 'corruption')
            end
          end
        end

        let(:list_source_rpm_files) do
          -> { Dir.glob(File.join(source_path, '**', '*.rpm')) }
        end

        let(:list_source_drpm_files) do
          -> { Dir.glob(File.join(source_path, '**', '*.drpm')) }
        end

        let(:list_dedup_rpm_files) do
          -> { Dir.glob(File.join(dedup_path, '**', '*.rpm')) }
        end

        let(:list_dedup_drpm_files) do
          -> { Dir.glob(File.join(dedup_path, '**', '*.drpm')) }
        end

        it 'removes corrupted source rpm files' do
          expect { deduplicate_mirror }
            .to change { list_source_rpm_files.call.length }
            .from(4).to(0)
        end

        it 'untracks corrupted source rpm files in the database' do
          expect { deduplicate_mirror }
            .to change { DownloadedFile.where(local_path: list_source_rpm_files.call).length }
            .from(4).to(0)
        end

        it 'removes corrupted source drpm files' do
          expect { deduplicate_mirror }
            .to change { list_source_drpm_files.call.length }
            .from(2).to(0)
        end

        it 'untracks corrupted source drpm files in the database' do
          expect { deduplicate_mirror }
            .to change { DownloadedFile.where(local_path: list_source_drpm_files.call).length }
            .from(2).to(0)
        end

        it 'downloads new rpm files instead of deduplicating from corrupted ones' do
          source_files_content = list_source_rpm_files.call
            .map { |file| [File.basename(file), File.read(file)] }

          deduplicate_mirror

          aggregate_failures 'compare files content' do
            list_dedup_rpm_files.call.each do |target_file|
              _, source_content = source_files_content
                .find { |name, _| target_file.include?(name) }

              expect(File.read(target_file)).not_to eq(source_content)
              expect(File.stat(target_file).nlink).to eq(1)
            end
          end
        end

        it 'tracks new rpm files which would be deduplicated' do
          expect { deduplicate_mirror }
            .to change { list_dedup_rpm_files.call.length }
            .from(0).to(4)
        end

        it 'downloads new drpm files instead of deduplicating from corrupted ones' do
          source_files_content = list_source_drpm_files.call
            .map { |file| [File.basename(file), File.read(file)] }

          deduplicate_mirror

          aggregate_failures 'compare files content' do
            list_dedup_drpm_files.call.each do |target_file|
              _, source_content = source_files_content
                .find { |name, _| target_file.include?(name) }

              expect(File.read(target_file)).not_to eq(source_content)
              expect(File.stat(target_file).nlink).to eq(1)
            end
          end
        end

        it 'tracks new drpm files which would be deduplicated' do
          expect { deduplicate_mirror }
            .to change { list_dedup_drpm_files.call.length }
            .from(0).to(2)
        end
      end
    end

    xcontext 'with cached metadata' do
      let(:mirroring_dir) do
        FileUtils.cp_r(file_fixture('dummy_product'), File.join(@tmp_dir, 'dummy_product'))
        @tmp_dir
      end
      let(:rmt_mirror) do
        described_class.new(
          mirroring_base_dir: mirroring_dir,
          logger: logger,
          mirror_src: false
        )
      end

      let(:mirror_params) do
        {
          repository_url: 'http://localhost/dummy_product/product/',
          local_path: '/dummy_product/product/',
          auth_token: 'repo_auth_token'
        }
      end

      let(:timestamp) { 'Mon, 18 May 2020 09:24:25 GMT' }

      before do
        metadata_files = [
          File.join(mirroring_dir, 'dummy_product', 'product.license', '**'),
          File.join(mirroring_dir, 'dummy_product', 'product', 'repodata', '**')
        ].reduce([]) { |files, path| files + Dir.glob(path) }
        metadata_files.each { |file| FileUtils.touch(file, mtime: Time.parse(timestamp).utc) }

        VCR.use_cassette 'mirroring_product_with_cached_metadata' do
          rmt_mirror.mirror(**mirror_params)
        end
      end

      it 'downloads rpm files' do
        rpm_entries = Dir.entries(File.join(@tmp_dir, 'dummy_product/product/')).select { |entry| entry =~ /\.rpm$/ }
        expect(rpm_entries.length).to eq(4)
      end

      it 'preserves metadata timestamps' do
        expect(File.mtime("#{mirroring_dir}/dummy_product/product/repodata/repomd.xml")).to eq(Time.parse(timestamp).utc)
      end
    end
  end

end
