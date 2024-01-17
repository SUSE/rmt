require 'rails_helper'

describe RMT::CLI::Export, :with_fakefs do
  let(:path) { '/mnt/usb' }

  describe 'settings' do
    include_examples 'handles non-existing path'
    include_examples 'handles non-writable path'
    let(:repository) { create :repository, mirroring_enabled: true, id: 123 }
    let(:command) { described_class.start(['settings', path]) }

    before do
      repository
      create :repository, mirroring_enabled: false
    end

    it 'writes ids of enabled repos to file' do
      FileUtils.mkdir_p path
      expect { command }.to output(/Settings saved at #{path}/).to_stdout
      expected_filename = File.join(path, 'repos.json')
      expected_json = [{ url: repository.external_url, auth_token: repository.auth_token.to_s }].to_json
      expect(File.exist?(expected_filename)).to be true
      expect(File.read(expected_filename).chomp).to eq expected_json
    end

    context 'relative path' do
      let(:path) { '/mnt/usb/../usb' }

      it 'writes ids of enabled repos to file' do
        FileUtils.mkdir_p path
        expect { command }.to output(%r{Settings saved at /mnt/usb}).to_stdout
        expected_filename = File.join('/mnt/usb', 'repos.json')
        expected_json = [{ url: repository.external_url, auth_token: repository.auth_token.to_s }].to_json
        expect(File.exist?(expected_filename)).to be true
        expect(File.read(expected_filename).chomp).to eq expected_json
      end
    end
  end

  describe 'data' do
    include_examples 'handles non-existing path'
    include_examples 'handles non-writable path'

    let(:command) { described_class.start(['data', path]) }

    it 'triggers export to path' do
      FileUtils.mkdir_p path

      expect_any_instance_of(RMT::SCC).to receive(:export).with(path)
      command
    end

    context 'relative path' do
      let(:path) { '/mnt/usb/../usb' }

      it 'triggers export to path' do
        FileUtils.mkdir_p path

        expect_any_instance_of(RMT::SCC).to receive(:export).with('/mnt/usb')
        command
      end
    end
  end

  describe 'repos' do
    let(:command) { described_class.start(['repos', path]) }

    let(:mirror_double) { instance_double('RMT::Mirror') }
    let(:suma_product_tree_double) { instance_double('RMT::Mirror::SumaProductTree') }
    let(:repo_json) { "#{path}/repos.json" }
    let(:repository1) { create :repository, mirroring_enabled: true, auth_token: 'foobar' }
    let(:repository2) { create :repository, mirroring_enabled: true }
    let(:repo_settings) do
      [
        { url: repository1.external_url, auth_token: repository1.auth_token },
        { url: repository2.external_url, auth_token: '' }
      ]
    end

    before do
      # Stub `needs_path` implementation since we can not stub `needs_path` directly
      # because of thor. See: https://github.com/rails/thor/blob/f1ba900585afecfa13b7fff36968fca3e305c371/lib/thor.rb#L567
      allow(File).to receive(:directory?).and_return(true)
      allow(File).to receive(:writable?).and_return(true)

      allow(File).to receive(:exist?).with(repo_json).and_return(true)
      allow(File).to receive(:read).with(repo_json).and_return(repo_settings.to_json.to_s)

      allow(RMT::Mirror::SumaProductTree).to receive(:new).and_return(suma_product_tree_double)
      allow(suma_product_tree_double).to receive(:mirror)
    end

    context 'suma product tree mirror with exception' do
      it 'outputs exception message' do
        allow_any_instance_of(RMT::Mirror).to receive(:mirror_now)

        expect(suma_product_tree_double).to receive(:mirror).and_raise(RMT::Mirror::Exception, 'black mirror')
        expect_any_instance_of(RMT::Logger).to receive(:warn).with(/black mirror/)
        command
      end
    end

    context 'with missing repos.json file' do
      it 'outputs a warning' do
        allow(File).to receive(:exist?).with(repo_json).and_return(false)

        expect { command }.to raise_error(SystemExit)
          .and(output("#{File.join(path, 'repos.json')} does not exist.\n").to_stderr)
      end
    end

    context 'with valid repo ids' do
      let(:mirror_repo) { instance_double(RMT::Mirror) }

      before do
        allow(RMT::Mirror).to receive(:new).with(
          repository: instance_of(Repository),
          logger: anything,
          mirroring_base_dir: anything,
          mirror_sources: anything,
          is_airgapped: true
        ).and_return(mirror_repo)
      end

      it 'reads repo ids from file at path and mirrors these repos' do
        expect(mirror_repo).to receive(:mirror_now).twice
        command
      end

      context 'with exceptions during mirroring' do
        it 'outputs exception message' do
          allow(mirror_repo).to receive(:mirror_now).and_raise(RMT::Mirror::Exception, 'black mirror')
          expect { command }.to output(/black mirror/).to_stderr
        end
      end
    end
  end
end
