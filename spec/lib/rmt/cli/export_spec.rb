require 'rails_helper'
# rubocop:disable RSpec/NestedGroups

describe RMT::CLI::Export do
  let(:path) { '/mnt/usb' }

  describe 'settings' do
    include_examples 'handles non-existing path'
    let(:repository) { create :repository, mirroring_enabled: true, id: 123 }
    let(:command) { described_class.start(['settings', path]) }

    before do
      repository
      create :repository, mirroring_enabled: false
    end

    it 'writes ids of enabled repos to file' do
      FakeFS.with_fresh do
        FileUtils.mkdir_p path
        expect { command }.to output(/Settings saved/).to_stdout
        expected_filename = File.join(path, 'repos.json')
        expected_json = [{ url: repository.external_url, auth_token: repository.auth_token.to_s }].to_json
        expect(File.exist?(expected_filename)).to be true
        expect(File.read(expected_filename).chomp).to eq expected_json
      end
    end
  end

  describe 'data' do
    include_examples 'handles non-existing path'

    let(:command) { described_class.start(['data', path]) }

    it 'triggers export to path' do
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
    let(:mirror_double) { instance_double('RMT::Mirror') }
    let(:repo_settings) do
      [
        { url: 'http://foo.bar/repo1', auth_token: 'foobar' },
        { url: 'http://foo.bar/repo2', auth_token: '' }
      ]
    end

    context 'with missing repos.json file' do
      it 'outputs a warning' do
        FakeFS.with_fresh do
          FileUtils.mkdir_p path

          expect { command }.to output("#{File.join(path, 'repos.json')} does not exist.\n").to_stderr
        end
      end
    end

    context 'with valid repo ids' do
      before do
        expect(RMT::Mirror).to receive(:from_url).with('http://foo.bar/repo1', 'foobar', base_dir: path, to_offline: true).once.and_return(mirror_double)
        expect(RMT::Mirror).to receive(:from_url).with('http://foo.bar/repo2', '', base_dir: path, to_offline: true).once.and_return(mirror_double)
      end

      it 'reads repo ids from file at path and mirrors these repos' do
        FakeFS.with_fresh do
          FileUtils.mkdir_p path
          File.write("#{path}/repos.json", repo_settings.to_json)

          expect(mirror_double).to receive(:mirror).twice
          expect { command }.to output(/Mirroring repository/).to_stdout
        end
      end

      context 'with exceptions during mirroring' do
        it 'outputs exception message' do
          FakeFS.with_fresh do
            FileUtils.mkdir_p path
            File.write("#{path}/repos.json", repo_settings.to_json)

            expect(mirror_double).to receive(:mirror)
            expect(mirror_double).to receive(:mirror).and_raise(RMT::Mirror::Exception, 'black mirror')
            expect { command }.to output(/black mirror/).to_stderr.and output(/Mirroring repository/).to_stdout
          end
        end
      end
    end
  end
end
