require 'rails_helper'

RSpec.describe RMT::Mirror::Base do
  subject { described_class.new(logger: logger, base_dir: base_dir, repository: repository, mirror_sources: false, airgapped: false) }

  let(:logger) { RMT::Logger.new('/dev/null') }
  let(:base_dir) { '/rspec/repository/' }
  let(:temp) { '/temp/path/' }

  let(:repository) do
    create :repository,
           name: 'HYPE product repository 15.3',
           external_url: 'https://updates.suse.com/update/hype/15.3/backports/'
  end

  let(:downloader) { double('downloader') }

  before do
    # Make all protected methods public here, to allow testing them properly
    described_class.send(:public, *described_class.protected_instance_methods)

    allow(subject).to receive(:downloader).and_return(downloader)
  end

  describe '#create_temp' do
    let(:error) { ArgumentError.new('parent directory is not sticky') }

    it 'creates the desired temp directories' do
      expect(Dir).to receive(:mktmpdir).with('one').and_return('/tmp/rspec-one')
      expect(Dir).to receive(:mktmpdir).with('two').and_return('/tmp/rspec-two')
      expect(Dir).to receive(:mktmpdir).with('three').and_return('/tmp/rspec-three')

      subject.create_temp(:one, :two, :three)

      expect(subject.temp_directories.keys).to match(%i[one two three])
      expect(subject.temp_directories[:two]).to match('/tmp/rspec-two')
    end


    it 'fails when it could not create the temp directory' do
      expect(Dir).to receive(:mktmpdir).and_raise(error)

      expect { subject.create_temp(:one) }.to raise_error(RMT::Mirror::Exception, /parent directory/)
    end
  end

  describe '#temp' do
    let(:temp_path) { '/tmp/path/' }

    it 'gives back the created temp directory' do
      expect(Dir).to receive(:mktmpdir).and_return(temp_path)
      subject.create_temp(:test)

      expect(subject.temp(:test)).to eq(temp_path)
    end

    it 'raises if an non existing temp directory is accessed' do
      expect { subject.temp(:does_not_exist) }.to raise_error(RMT::Mirror::Exception)
    end
  end

  describe '#download_cached!' do
    let(:resource) { 'somedir/somefile.json' }

    it 'downloads the resource' do
      expect(downloader).to receive(:download_multi)

      ref = subject.download_cached!(resource, to: temp)

      expect(ref.local_path).to match(File.join(temp, resource))
      expect(ref.cache_path).to match(File.join(subject.repository_dir, resource))
      expect(ref.remote_path).to match(URI.join(repository.external_url, resource))
    end
  end

  describe '#optional' do
    it 'logs the error occured and continues' do
      expect(logger).to receive(:debug).with('Skipped download licenses: not found')

      subject.optional('download licenses') do
        raise 'not found'
      end
    end
  end
end
