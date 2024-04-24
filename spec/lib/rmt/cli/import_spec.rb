require 'rails_helper'

describe RMT::CLI::Import, :with_fakefs do
  let(:path) { '/mnt/usb' }

  describe 'data' do
    include_examples 'handles non-existing path'
    include_examples 'handles lockfile exception'

    subject(:command) { described_class.start(['data', path]) }

    it 'triggers import to path' do
      FileUtils.mkdir_p path

      expect_any_instance_of(RMT::SCC).to receive(:import).with(path)
      command
    end

    context 'with unexpected error being raised' do
      it 'removes lockfile and re-raises error' do
        FileUtils.mkdir_p path
        allow_any_instance_of(RMT::SCC).to receive(:import).with(path).and_raise(RuntimeError)

        expect { command }.to raise_error(RuntimeError)
      end
    end

    context 'with relative path' do
      let(:path) { '/mnt/usb/../usb' }

      it 'triggers import to path' do
        FileUtils.mkdir_p path

        expect_any_instance_of(RMT::SCC).to receive(:import).with('/mnt/usb')
        command
      end
    end
  end

  describe 'repos' do
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

    include_examples 'handles lockfile exception'

    subject(:command) { described_class.start(['repos', path]) }

    let(:repository1) { create :repository, mirroring_enabled: true, auth_token: 'foobar' }
    let(:repository2) { create :repository, mirroring_enabled: true }

    let(:mirror_double) { instance_double('RMT::Mirror') }
    let(:suma_product_tree_double) { instance_double('RMT::Mirror::SumaProductTree') }

    let(:repo_json) { "#{path}/repos.json" }

    let(:repo1_local_path) { repo_url_to_local_path(path, repository1.external_url) }
    let(:repo2_local_path) { repo_url_to_local_path(path, repository2.external_url) }
    let(:repo_settings) do
      [
        { url: repository1.external_url, auth_token: repository1.auth_token.to_s },
        { url: repository2.external_url, auth_token: repository2.auth_token.to_s }
      ]
    end


    it 'mirrors repo1 and repo2' do
      allow(RMT::Mirror).to receive(:new).with(
        repository: have_attributes(external_url: repo1_local_path),
        logger: anything,
        mirroring_base_dir: anything,
        mirror_sources: anything,
        is_airgapped: true
      ).and_return(mirror_double)

      allow(RMT::Mirror).to receive(:new).with(
        repository: have_attributes(external_url: repo2_local_path),
        logger: anything,
        mirroring_base_dir: anything,
        mirror_sources: anything,
        is_airgapped: true
      ).and_return(mirror_double)

      expect(mirror_double).to receive(:mirror_now).twice

      command
    end

    context 'no repos.json file' do
      it 'warns that repos.json does not exist' do
        allow(File).to receive(:exist?).with(repo_json).and_return(false)

        expect { command }.to raise_error(SystemExit)
          .and output('').to_stdout
          .and output(/repos.json does not exist/).to_stderr
      end
    end

    context 'suma product tree mirror with exception' do
      it 'outputs exception message' do
        allow(RMT::Mirror).to receive(:new).and_return(mirror_double)
        allow(suma_product_tree_double).to receive(:mirror).and_raise(RMT::Mirror::Exception, 'black mirror')
        expect(mirror_double).to receive(:mirror_now).twice

        expect { command }.to output(/black mirror/).to_stdout
      end
    end

    context 'repository does not exist in database' do
      let(:missing_repo_url) { 'http://foo.bar.missing/repo/bar' }
      let(:missing_local_path) { repo_url_to_local_path(path, missing_repo_url) }
      let(:repo_settings) do
        [
          { url: missing_repo_url, auth_token: '' }
        ]
      end

      let(:error_message) { "repository by URL #{missing_repo_url} does not exist in database" }

      it 'tries to mirrors repo2, but outputs warning' do
        expect { command }.to output(/#{error_message}/).to_stderr
          .and output('').to_stdout
      end
    end

    context 'with exceptions during mirroring' do
      it 'mirrors repo2 when repo1 raised an exception' do
        allow(RMT::Mirror).to receive(:new).and_return(mirror_double)

        expect(mirror_double).to receive(:mirror_now).and_raise(RMT::Mirror::Exception, 'black mirror')
        expect(mirror_double).to receive(:mirror_now)

        expect { command }.to output(/black mirror/).to_stdout
      end
    end
  end
end
