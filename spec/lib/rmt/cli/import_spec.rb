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
  end

  describe 'repos' do
    include_examples 'handles non-existing path'
    include_examples 'handles lockfile exception'

    subject(:command) { described_class.start(['repos', path]) }

    let(:repo1) { create :repository, mirroring_enabled: true, auth_token: 'foobar' }
    let(:repo2) { create :repository, mirroring_enabled: true }
    let(:repo1_local_path) { repo_url_to_local_path(path, repo1.external_url) }
    let(:repo2_local_path) { repo_url_to_local_path(path, repo2.external_url) }
    let(:mirror_double) { instance_double 'RMT::Mirror' }
    let(:repo_settings) do
      [
        { url: repo1.external_url, auth_token: repo1.auth_token.to_s },
        { url: repo2.external_url, auth_token: repo2.auth_token.to_s }
      ]
    end

    context 'no repos.json file' do
      it 'warns that repos.json does not exist' do
        FileUtils.mkdir_p path
        expect { command }.to output('').to_stdout.and output(/repos.json does not exist/).to_stderr
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

      it 'tries to mirrors repo2, but outputs warning' do
        FileUtils.mkdir_p path
        File.write("#{path}/repos.json", repo_settings.to_json)

        expect { command }.to output(/repository by url #{missing_repo_url} does not exist in database/).to_stderr.and output('').to_stdout
      end
    end

    context 'without exception' do
      before do
        expect(mirror_double).to receive(:mirror).twice
        expect(RMT::Mirror).to receive(:from_url).with(repo1_local_path, repo1.auth_token, base_dir: RMT::DEFAULT_MIRROR_DIR,
                                                       repository_url: repo1.external_url, to_offline: true).and_return(mirror_double)
        expect(RMT::Mirror).to receive(:from_url).with(repo2_local_path, repo2.auth_token, base_dir: RMT::DEFAULT_MIRROR_DIR,
                                                       repository_url: repo2.external_url, to_offline: true).and_return(mirror_double)
      end

      it 'mirrors repo1' do
        FileUtils.mkdir_p path
        File.write("#{path}/repos.json", repo_settings.to_json)

        expect { command }.to output(/Mirroring repository #{repo1.name}/).to_stdout.and output('').to_stderr
      end

      it 'mirrors repo2' do
        FileUtils.mkdir_p path
        File.write("#{path}/repos.json", repo_settings.to_json)

        expect { command }.to output(/Mirroring repository #{repo2.name}/).to_stdout.and output('').to_stderr
      end
    end

    context 'with exceptions during mirroring' do
      let(:mirror_error_double) { instance_double 'RMT::Mirror' }
      let(:repo_settings) do
        [
          { url: repo1.external_url, auth_token: repo1.auth_token.to_s },
          { url: repo2.external_url, auth_token: repo2.auth_token.to_s }
        ]
      end

      before do
        expect(mirror_error_double).to receive(:mirror).once.and_raise(RMT::Mirror::Exception, 'black mirror')
        expect(mirror_double).to receive(:mirror).once
        expect(RMT::Mirror).to receive(:from_url).with(repo1_local_path, repo1.auth_token, base_dir: RMT::DEFAULT_MIRROR_DIR,
                                                       repository_url: repo1.external_url, to_offline: true).and_return(mirror_error_double)
        expect(RMT::Mirror).to receive(:from_url).with(repo2_local_path, repo2.auth_token, base_dir: RMT::DEFAULT_MIRROR_DIR,
                                                       repository_url: repo2.external_url, to_offline: true).and_return(mirror_double)
      end

      it 'tries to mirror repo1' do
        FileUtils.mkdir_p path
        File.write("#{path}/repos.json", repo_settings.to_json)

        expect { command }.to output("black mirror\n").to_stderr.and output(/Mirroring repository #{repo1.name}/).to_stdout
      end
      it 'tries to mirror repo2' do
        FileUtils.mkdir_p path
        File.write("#{path}/repos.json", repo_settings.to_json)

        expect { command }.to output("black mirror\n").to_stderr.and output(/Mirroring repository #{repo2.name}/).to_stdout
      end
    end
  end
end
