require 'rails_helper'

RSpec.describe RMT::Mirror::FileReference do
  subject(:file_reference) do
    described_class.new(relative_path: relative_path,
                        base_dir: base_dir,
                        base_url: base_url,
                        cache_dir: cache_dir)
  end

  around do |example|
    example.run
    FileUtils.remove_entry(tmp_dir, true)
  end

  let!(:tmp_dir) { Dir.mktmpdir('rmt') }
  let(:relative_path) { 'dummy_dir/dummy_file.ext' }
  let(:base_dir) { '/rmt/mirror/path' }
  let(:base_url) { 'https://www.repourl.com' }
  let(:cache_dir) { nil }

  describe '#cache_path' do
    context 'when instantiated with a cache dir path' do
      let(:cache_dir) { '/rmt/cache/dir' }

      it 'returns the absolute cache path' do
        expect(file_reference.cache_path).to eq('/rmt/cache/dir/dummy_dir/dummy_file.ext')
      end
    end

    context 'when instantiated without a cache dir path' do
      subject(:file_reference) do
        described_class.new(relative_path: relative_path,
                            base_dir: base_dir,
                            base_url: base_url)
      end

      it 'returns nil' do
        expect(file_reference.cache_path).to be_nil
      end
    end
  end

  describe '#cache_timestamp' do
    context 'when instantiated with a cache dir path and absolute cache path exists' do
      before do
        absolute_path = File.join(cache_dir, relative_path)
        FileUtils.mkpath(File.dirname(absolute_path))
        FileUtils.touch(absolute_path, mtime: timestamp)
      end

      let(:cache_dir) { tmp_dir }
      let(:timestamp) { Time.parse('Fri, 18 Sep 2020 18:13:57 GMT').utc }

      it "returns the file's mtime" do
        expect(file_reference.cache_timestamp).to eq(timestamp)
      end
    end

    context 'when instantiated with a cache dir path and absolute cache path does not exists' do
      let(:cache_dir) { tmp_dir }

      it "returns the file's mtime" do
        expect(file_reference.cache_timestamp).to be_nil
      end
    end

    context 'when instantiated without a cache dir path' do
      subject(:file_reference) do
        described_class.new(relative_path: relative_path,
                            base_dir: base_dir,
                            base_url: base_url)
      end

      it 'returns nil' do
        expect(file_reference.cache_timestamp).to be_nil
      end
    end
  end

  describe '#local_path' do
    it 'returns the absolute local path' do
      expect(file_reference.local_path).to eq('/rmt/mirror/path/dummy_dir/dummy_file.ext')
    end

    context "when the relative path containts '..'" do
      let(:relative_path) { '../dummy/relative/path/file.ext' }

      it "returns the absolute local path replacing '..' w/ '__'" do
        expect(file_reference.local_path).to eq('/rmt/mirror/path/__/dummy/relative/path/file.ext')
      end
    end
  end

  describe '#remote_path' do
    it 'returns a URI::Generic instance' do
      expect(file_reference.remote_path).to be_kind_of(URI::Generic)
    end

    it 'returns the absolute remote path' do
      expect(file_reference.remote_path.to_s).to eq('https://www.repourl.com/dummy_dir/dummy_file.ext')
    end
  end

  describe 'build_from_metadata' do
    subject(:file_reference) do
      described_class.build_from_metadata(metadata_reference,
                                          base_dir: base_dir,
                                          base_url: base_url,
                                          cache_dir: cache_dir)
    end

    let(:metadata_reference) do
      instance_double(RepomdParser::Reference,
                      location: relative_path,
                      arch: 'x86_64',
                      checksum: '2c4e3fa1624bd23221eecdda9c7fcefad042992a9eaed227d06dd8210cfe2821',
                      checksum_type: 'SHA256',
                      size: 2020,
                      type: :primary)
    end

    it { is_expected.to be_instance_of(described_class) }

    it 'returns an object with metadata attributes' do
      expect(file_reference).to have_attributes(
        arch: metadata_reference.arch,
        checksum: metadata_reference.checksum,
        checksum_type: metadata_reference.checksum_type,
        size: metadata_reference.size,
        type: metadata_reference.type
      )
    end
  end
end
