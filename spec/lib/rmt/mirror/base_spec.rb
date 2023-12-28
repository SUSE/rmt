require 'rails_helper'

describe RMT::Mirror::Base do
  subject(:base) { described_class.new(**configuration) }

  let(:configuration) do
    {
      repository: repository,
      logger: RMT::Logger.new('/dev/null'),
      mirroring_base_dir: '/rspec/repository'
    }
  end

  let(:repository) do
    create :repository,
           name: 'HYPE product repository debian 15.3',
           external_url: 'https://updates.suse.com/update/hype/15.3/product/'
  end

  let(:downloader) { instance_double('downloader') }

  before do
    # Make all protected methods public for testing purpose
    described_class.send(:public, *described_class.protected_instance_methods)

    allow(base).to receive(:downloader).and_return(downloader)
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

    it 'creates the desired temp directories' do
      allow(Dir).to receive(:mktmpdir).with('metadata').and_return('/tmp/rspec-metadata')
      allow(Dir).to receive(:mktmpdir).with('license').and_return('/tmp/rspec-license')

      base.create_temp_dir(:metadata)
      base.create_temp_dir(:license)

      expect(base.temp_dirs.keys).to match(%i[metadata license])
      expect(base.temp_dirs[:metadata]).to match('/tmp/rspec-metadata')
    end

    it 'fails when it could not create the temp directory' do
      allow(Dir).to receive(:mktmpdir).and_raise(error)

      expect { base.create_temp_dir(:metadata) }.to raise_error(RMT::Mirror::Exception, /parent directory/)
    end
  end

  describe '#cleanup_temp_dirs' do
    let(:temp_metadata) { '/tmp/metadata' }
    let(:temp_licenses) { '/tmp/licenses' }

    before do
      allow(Dir).to receive(:mktmpdir).with('metadata').and_return(temp_metadata)
      allow(Dir).to receive(:mktmpdir).with('license').and_return(temp_licenses)

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
    let(:temp_path) { '/tmp/path/' }

    it 'gives back the created temp directory' do
      allow(Dir).to receive(:mktmpdir).and_return(temp_path)

      base.create_temp_dir(:test)
      expect(base.temp(:test)).to eq(temp_path)
    end

    it 'raises if an non existing temp directory is accessed' do
      expect { base.temp(:does_not_exist) }.to raise_error(RMT::Mirror::Exception)
    end
  end

  describe '#check_signature' do
    let(:config) do
      {
        base_dir: '/tmp',
        base_url: 'https://updates.suse.de/'
      }
    end
    let(:signature_file) { RMT::Mirror::FileReference.new(relative_path: 'repo.gpg', **config) }
    let(:key_file) { RMT::Mirror::FileReference.new(relative_path: 'repo.key', **config) }
    let(:metadata) { RMT::Mirror::FileReference.new(relative_path: 'metadata', **config) }
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

    context 'has invalid or no signature' do
      it 'raises exception' do
        expect(downloader).to receive(:download_multi).and_raise(RMT::Downloader::Exception, 'foo')
        expect do
          base.check_signature(key_file: key_file, signature_file: signature_file, metadata_file: metadata)
        end.to raise_error(/foo/)
      end
    end
  end

  describe '#replace_directory' do
    let(:src) { '/source/path' }
    let(:dest) { '/destination/path' }
    let(:backup) { '/destination/.backup_path' }

    it 'moves content from source to destination' do
      expect(Dir).to receive(:exist?).with(backup).and_return(false)
      expect(Dir).to receive(:exist?).with(dest).and_return(false)
      expect(FileUtils).to receive(:mv).with(src, dest, force: true)
      expect(FileUtils).to receive(:chmod).with(0o755, dest)
      base.replace_directory(source: src, destination: dest)
    end

    it 'removes the backup directory if it already exists' do
      expect(Dir).to receive(:exist?).with(backup).and_return(true)
      expect(FileUtils).to receive(:remove_entry).with(backup)
      expect(Dir).to receive(:exist?).with(dest).and_return(false)
      expect(FileUtils).to receive(:mv).with(src, dest, force: true)
      expect(FileUtils).to receive(:chmod).with(0o755, dest)
      base.replace_directory(source: src, destination: dest)
    end

    it 'creates an backup directory if the destination directory already exists' do
      expect(Dir).to receive(:exist?).with(backup).and_return(false)
      expect(Dir).to receive(:exist?).with(dest).and_return(true)
      expect(FileUtils).to receive(:mv).with(dest, backup)
      expect(FileUtils).to receive(:mv).with(src, dest, force: true)
      expect(FileUtils).to receive(:chmod).with(0o755, dest)
      base.replace_directory(source: src, destination: dest)
    end

    it 'yields when block is given' do
      expect { |b| base.replace_directory(source: src, destination: dest, with_backup: false, &b) }.to yield_with_args
    end

    it 'fails on file system errors' do
      expect(Dir).to receive(:exist?).with(backup).and_raise(StandardError)
      expect { base.replace_directory(source: src, destination: dest) }.to raise_exception(/Error while moving directory/)
    end
  end

  describe '#need_to_download?' do
    it 'does not mirror source files'
    it 'does not download if the file exists locally'
    it 'deduplicates the file if it exists'
  end
end
