require 'rails_helper'

# rubocop:disable RSpec/MultipleExpectations

RSpec.describe RMT::CLI::Export do
  let(:path) { '/mnt/usb' }

  shared_examples 'handles non-existing path' do
    context 'with non-existing path' do
      it 'complains and exits' do
        FakeFS.with_fresh do
          expect { command }.to output("#{path} is not a directory.\n").to_stderr
        end
      end
    end
  end

  describe 'settings' do
    include_examples 'handles non-existing path'

    let(:command) { described_class.start(['settings', path]) }

    before do
      create :repository, mirroring_enabled: true, id: 123
      create :repository, mirroring_enabled: false
    end

    it 'writes ids of enabled repos to file' do
      FakeFS.with_fresh do
        FileUtils.mkdir_p path
        command
        expected_filename = File.join(path, 'repos.json')
        expect(File.exist?(expected_filename)).to be true
        expect(File.read(expected_filename).chomp).to eq '[123]'
      end
    end
  end

  describe 'data' do
    include_examples 'handles non-existing path'

    let(:command) { described_class.start(['data', path]) }

    it 'calls sync with special params' do
      FakeFS.with_fresh do
        FileUtils.mkdir_p path
        expect_any_instance_of(RMT::SCC).to receive(:export).with(path)
        command
      end
    end
  end

  describe 'repos' do
    include_examples 'handles non-existing path'

    let(:command) { described_class.start(['repos', path]) }

    let(:repo_ids) { [42, 69] }
    let!(:repos) do
      repo_ids.map { |id| create :repository, id: id }
    end
    let(:mirror_double) do
      double = instance_double(RMT::Mirror)
      expect(double).to receive(:mirror).exactly(2).times
      double
    end

    before { create :repository, id: 666, mirroring_enabled: true }

    it 'reads repo ids from file at path and mirrors these repos' do
      FakeFS.with_fresh do
        FileUtils.mkdir_p path
        File.write("#{path}/repos.json", repo_ids.to_json)

        expect(RMT::Mirror).to receive(:new).exactly(2).times { mirror_double }
        command
      end
    end
  end
end
