require 'rails_helper'

describe RMT::Mirror::Base do
  subject(:base) { described_class.new(**mirror_configuration) }

  let(:mirror_configuration) do
    {
      repository: repository,
      logger: logger,
      mirroring_base_dir: '/rspec/repository',
      mirror_sources: enable_source_mirroring
    }
  end
  let(:enable_source_mirroring) { false }

  let(:repository) do
    create :repository,
           name: 'HYPE product repository debian 15.3',
           external_url: 'https://updates.suse.com/update/hype/15.3/product/'
  end

  let(:downloader) { instance_double('downloader') }

  let(:logger) { RMT::Logger.new('/dev/null') }

  before do
    # Make all protected methods public for testing purpose
    described_class.send(:public, *described_class.protected_instance_methods)

    allow(base).to receive(:downloader).and_return(downloader)
    allow(downloader).to receive(:downloaded_files_count)
    allow(downloader).to receive(:downloaded_files_size)
  end

  describe '#mirror' do
    it 'mirrors repositories and licenses' do
      expect(base).to receive(:mirror_implementation)
      expect(base).to receive(:cleanup_temp_dirs)
      expect(base).to receive(:cleanup_stale_metadata)
      base.mirror
    end

    it 'throws an exception if mirroring fails' do
      allow(base).to receive(:mirror_implementation).and_raise(RMT::Mirror::Exception)
      expect(base).to receive(:cleanup_temp_dirs)
      expect(base).to receive(:cleanup_stale_metadata)
      expect { base.mirror }.to raise_error(RMT::Mirror::Exception)
    end
  end

  describe '#mirror_implementation' do
    it 'will implement the main mirroring logic' do
      expect { base.mirror_implementation }.to raise_error('Not implemented!')
    end
  end

  describe '#download_cached' do
    let(:resource) { 'somedir/somefile.json' }
    let(:temp) { '/temp/path' }

    it 'downloads the resource' do
      expect(downloader).to receive(:download_multi)

      ref = base.download_cached!(resource, to: temp)

      expect(ref.local_path).to match(File.join(temp, resource))
      expect(ref.cache_path).to match(File.join(base.repository_path(resource)))
      expect(ref.remote_path).to match(URI.join(repository.external_url, resource))
    end
  end

  describe '#create_temp_dir' do
    let(:error) { ArgumentError.new('parent directory is not sticky') }
    let(:metadata_tmp_path) { base.repository_path('.tmp_metadata') }
    let(:license_tmp_path) { base.repository_path('.tmp_license') }

    it 'creates the desired temp directories' do
      allow(FileUtils).to receive(:mkpath).with(metadata_tmp_path)
      allow(FileUtils).to receive(:mkpath).with(license_tmp_path)

      base.create_temp_dir(:metadata)
      base.create_temp_dir(:license)

      expect(base.temp_dirs.keys).to match(%i[metadata license])
      expect(base.temp_dirs[:metadata]).to match(metadata_tmp_path)
      expect(base.temp_dirs[:license]).to match(license_tmp_path)
    end

    it 'fails when it could not create the temp directory' do
      allow(FileUtils).to receive(:mkpath).and_raise(error)

      expect { base.create_temp_dir(:metadata) }.to raise_error(RMT::Mirror::Exception, /parent directory/)
    end
  end

  describe '#create_repository_path' do
    it 'creates the repository path' do
      allow(Dir).to receive(:exist?).and_return(false)
      expect(FileUtils).to receive(:mkpath).with('/rspec/repository/update/hype/15.3/product/')
      base.create_repository_path
    end

    it 'fails when it could not create the repository path' do
      allow(Dir).to receive(:exist?).and_return(false)
      allow(FileUtils).to receive(:mkpath).and_raise(StandardError)

      expect { base.create_repository_path }.to raise_error(RMT::Mirror::Exception, /Could not create local directory/)
    end
  end

  describe '#cleanup_temp_dirs' do
    let(:temp_metadata) { base.repository_path('.tmp_metadata') }
    let(:temp_licenses) { base.repository_path('.tmp_license') }

    before do
      allow(FileUtils).to receive(:mkpath).with(temp_metadata)
      allow(FileUtils).to receive(:mkpath).with(temp_licenses)

      base.create_temp_dir(:metadata)
      base.create_temp_dir(:license)
    end

    it 'removes all known temporary directories' do
      expect(FileUtils).to receive(:remove_entry).with(temp_metadata, force: true)
      expect(FileUtils).to receive(:remove_entry).with(temp_licenses, force: true)

      base.cleanup_temp_dirs

      expect(base.temp_dirs.size).to be_zero
    end
  end

  describe '#temp' do
    let(:temp_path) { base.repository_path('.tmp_test') }

    it 'gives back the created temp directory' do
      expect(FileUtils).to receive(:mkpath).with(temp_path)

      base.create_temp_dir(:test)
      expect(base.temp(:test)).to eq(temp_path)
    end

    it 'raises if an non existing temp directory is accessed' do
      expect { base.temp(:does_not_exist) }.to raise_error(RMT::Mirror::Exception)
    end
  end

  describe '#check_signature' do
    let(:ref_configuration) do
      {
        base_dir: '/tmp',
        base_url: 'https://updates.suse.de/'
      }
    end
    let(:signature_file) { RMT::Mirror::FileReference.new(relative_path: 'repo.gpg', **ref_configuration) }
    let(:key_file) { RMT::Mirror::FileReference.new(relative_path: 'repo.key', **ref_configuration) }
    let(:metadata) { RMT::Mirror::FileReference.new(relative_path: 'metadata', **ref_configuration) }
    let(:gpg_checker) do
      RMT::GPG.new(
        metadata_file: metadata.local_path,
        key_file: key_file.local_path,
        signature_file: signature_file.local_path,
        logger: nil
     )
    end

    context 'has valid signature' do
      it 'succeeds' do
        expect(downloader).to receive(:download_multi).with(match_array([key_file, signature_file]))
        expect_any_instance_of(RMT::GPG).to receive(:verify_signature)
        base.check_signature(key_file: key_file, signature_file: signature_file, metadata_file: metadata)
      end
    end

    context 'is unable to download the signature files' do
      it 'raises exception' do
        expect(downloader).to receive(:download_multi).and_raise(RMT::Downloader::Exception, 'foo')
        expect do
          base.check_signature(key_file: key_file, signature_file: signature_file, metadata_file: metadata)
        end.to raise_error(/foo/)
      end
    end

    context 'the signature file is missing' do
      let(:response) { Typhoeus::Response.new(code: 404, body: {}) }

      it 'creates a log entry' do
        allow(downloader).to receive(:download_multi).and_raise(RMT::Downloader::Exception.new('missing file', response: response))
        expect(logger).to receive(:info).with(/metadata signatures are missing/)
        base.check_signature(key_file: key_file, signature_file: signature_file, metadata_file: metadata)
      end
    end
  end

  describe '#download_enqueued' do
    before do
      base.enqueue(base.file_reference('enqueued_file', to: '/test/path/'))
    end

    it 'downloads enqueued contents and clear queue' do
      expect(downloader).to receive(:download_multi)
      expect(base.enqueued.count).to eq(1)
      base.download_enqueued
      expect(base.enqueued).to be_empty
    end
  end

  describe '#move_files' do
    let(:src) { '/source/path/*' }
    let(:dest) { '/destination/path' }

    it 'creates the destination directory if not yet existing' do
      allow(Dir).to receive(:exist?).with(dest).and_return(false)
      expect(FileUtils).to receive(:mkpath).with(dest)
      expect(FileUtils).to receive(:mv).with(Dir.glob(src), dest, force: true)

      base.move_files(glob: src, destination: dest)
    end

    it 'copies content from source to destination' do
      allow(Dir).to receive(:exist?).with(dest).and_return(true)
      expect(FileUtils).to receive(:mv).with(Dir.glob(src), dest, force: true)

      base.move_files(glob: src, destination: dest)
    end

    it 'fails on file system errors' do
      allow(Dir).to receive(:exist?).with(dest).and_return(true)
      allow(FileUtils).to receive(:mv).with(Dir.glob(src), dest, force: true).and_raise(StandardError)

      expect { base.move_files(glob: src, destination: dest) }.to raise_exception(/Error while moving files/)
    end

    it 'removes existing files when destination directory is empty' do
      allow(Dir).to receive(:exist?).with(dest).and_return(false)
      allow(Dir).to receive(:glob).with(src).and_return(%w[/source/path/newfile1.txt /source/path/newfile2.txt])
      allow(Dir).to receive(:glob).with(File.join(dest, '*')).and_return([])
      expect(FileUtils).to receive(:mkpath).with(dest)
      expect(FileUtils).to receive(:rm_rf).with([])
      expect(FileUtils).to receive(:mv).with(%w[/source/path/newfile1.txt /source/path/newfile2.txt], dest, force: true)

      base.move_files(glob: src, destination: dest, clean_before: true)
    end

    it 'handles errors during removal of existing files' do
      allow(Dir).to receive(:exist?).with(dest).and_return(true)
      existing_files = ['/destination/path/file1.txt']

      allow(Dir).to receive(:glob).with(File.join(dest, '*')).and_return(existing_files)
      allow(FileUtils).to receive(:rm_rf).with(existing_files).and_raise(StandardError.new('Remove failed'))

      expect do
        base.move_files(glob: src, destination: dest, clean_before: true)
      end.to raise_exception(/Error while moving files/)
    end

    it 'does not remove existing files when clean_before is false' do
      allow(Dir).to receive(:exist?).with(dest).and_return(true)
      allow(Dir).to receive(:glob).with(src).and_return(%w[/source/path/newfile1.txt /source/path/newfile2.txt])
      allow(Dir).to receive(:glob).with(File.join(dest, '*')).and_return(%w[/destination/path/existing1.txt /destination/path/existing2.txt])

      expect(FileUtils).not_to receive(:rm_rf)
      expect(FileUtils).to receive(:mv).with(%w[/source/path/newfile1.txt /source/path/newfile2.txt], dest, force: true)

      base.move_files(glob: src, destination: dest, clean_before: false)
    end

    it 'removes existing files when clean_before is true' do
      allow(Dir).to receive(:exist?).with(dest).and_return(true)
      existing_files = %w[/destination/path/file1.txt /destination/path/file2.txt]
      source_files = %w[/source/path/newfile1.txt /source/path/newfile2.txt]

      allow(Dir).to receive(:glob).with(File.join(dest, '*')).and_return(existing_files)
      allow(Dir).to receive(:glob).with(src).and_return(source_files)

      expect(FileUtils).to receive(:rm_rf).with(existing_files)
      expect(FileUtils).to receive(:mv).with(source_files, dest, force: true)

      base.move_files(glob: src, destination: dest, clean_before: true)
    end
  end

  describe '#need_to_download?' do
    let(:source_package) do
      ref = base.file_reference('neovim-0.9.4.src.rpm', to: '/test/path/')
      ref.arch = 'src'
      ref
    end

    let(:package) do
      ref = base.file_reference('neovim-0.9.4.deb', to: '/test/path/')
      ref.arch = 'x86_64'
      ref
    end

    context 'with source mirroring enabled' do
      let(:enable_source_mirroring) { true }

      it 'indicates downloading source files' do
        allow(base).to receive(:validate_local_file).with(source_package).and_return(false)
        allow(base).to receive(:deduplicate).with(source_package).and_return(false)

        expect(base.need_to_download?(source_package)).to be(true)
      end
    end

    it 'does not indicate downloading source packages if source mirroring is disabled' do
      expect(base.need_to_download?(source_package)).to be(false)
    end

    context 'with normal package' do
      it 'doesnt indicate if the package exists locally' do
        allow(base).to receive(:validate_local_file).with(package).and_return(true)
        allow(base).to receive(:deduplicate).with(package).and_return(false)

        expect(base.need_to_download?(package)).to be(false)
      end

      it 'does indicate if the package does not exist or match' do
        allow(base).to receive(:validate_local_file).with(package).and_return(false)
        allow(base).to receive(:deduplicate).with(package).and_return(false)

        expect(base.need_to_download?(package)).to be(true)
      end
    end

    it 'doesnt indicate if the package is duplicated in another repository' do
      allow(base).to receive(:validate_local_file).with(package).and_return(false)
      allow(base).to receive(:deduplicate).with(package).and_return(true)

      expect(base.need_to_download?(package)).to be(false)
    end
  end

  describe '#cleanup_stale_metadata' do
    let(:duplicated_repodata_path) { base.repository_path('repodata', 'repodata') }
    let(:old_backup_glob) { base.repository_path('.old_*') }
    let(:found_old_backup_files) do
      [
        base.repository_path('.old_repodata'),
        base.repository_path('.old_license')
      ]
    end

    context 'with repodata/repodata/' do
      it 'removes the directory' do
        allow(Dir).to receive(:exist?).with(duplicated_repodata_path).and_return(true)
        allow(Dir).to receive(:glob).with(old_backup_glob).and_return([])

        expect(FileUtils).to receive(:remove_entry).with(duplicated_repodata_path)

        base.cleanup_stale_metadata
      end
    end

    context 'with .old_repodata' do
      it 'removes stale .old_* backups' do
        allow(Dir).to receive(:exist?).with(duplicated_repodata_path).and_return(false)
        allow(Dir).to receive(:glob).with(old_backup_glob).and_return(found_old_backup_files)

        expect(FileUtils).to receive(:remove_entry).with(found_old_backup_files[0])
        expect(FileUtils).to receive(:remove_entry).with(found_old_backup_files[1])

        base.cleanup_stale_metadata
      end
    end

    context 'filesystem error' do
      it 'does not raise' do
        allow(Dir).to receive(:exist?).with(duplicated_repodata_path).and_return(false)
        allow(Dir).to receive(:glob).with(old_backup_glob).and_return(found_old_backup_files)
        allow(FileUtils).to receive(:remove_entry).with(found_old_backup_files[1]).and_raise(StandardError)

        expect(FileUtils).to receive(:remove_entry).with(found_old_backup_files[0])
        expect(base.logger).to receive(:debug).exactly(4).times

        base.cleanup_stale_metadata
      end
    end

    context 'without stale metadata' do
      it 'does not delete any directory' do
        allow(Dir).to receive(:exist?).with(duplicated_repodata_path).and_return(false)
        allow(Dir).to receive(:glob).with(old_backup_glob).and_return([])

        expect(FileUtils).not_to receive(:remove_entry)

        base.cleanup_stale_metadata
      end
    end
  end
end
