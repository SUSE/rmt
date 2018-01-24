require 'rails_helper'
# rubocop:disable RSpec/NestedGroups

describe RMT::CLI::Import do
  let(:path) { '/mnt/usb' }

  describe 'scc-data' do
    include_examples 'handles non-existing path'

    subject(:command) { described_class.start(['scc-data', path]) }

    it 'triggers import to path' do
      FakeFS.with_fresh do
        FileUtils.mkdir_p path

        expect_any_instance_of(RMT::SCC).to receive(:import).with(path)
        command
      end
    end
  end

  describe 'repos' do
    include_examples 'handles non-existing path'

    subject(:command) { described_class.start(['repos', path]) }

    let!(:repo1) { create :repository, mirroring_enabled: true, auth_token: 'foobar' }
    let!(:repo2) { create :repository, mirroring_enabled: true }

    let(:repo_settings) do
      [
        { url: repo1.external_url, auth_token: repo1.auth_token.to_s },
        { url: repo2.external_url, auth_token: repo2.auth_token.to_s }
      ]
    end
    let(:mirror_double) { instance_double 'RMT::Mirror' }

    context 'with repos marked for mirroring' do
      context 'triggers mirroring' do
        before do
          expect(mirror_double).to receive(:mirror).twice
          expect(RMT::Mirror).to receive(:from_repo_model).with(repo1, base_dir: RMT::DEFAULT_MIRROR_DIR, deduplication_enabled: false).and_return(mirror_double)
          expect(RMT::Mirror).to receive(:from_repo_model).with(repo2, base_dir: RMT::DEFAULT_MIRROR_DIR, deduplication_enabled: false).and_return(mirror_double)
        end

        it 'mirrors repo1' do
          FakeFS.with_fresh do
            FileUtils.mkdir_p path
            File.write("#{path}/repos.json", repo_settings.to_json)

            expect { command }.to output(/Mirroring repository #{repo1.name}/).to_stdout.and output('').to_stderr
          end
        end

        it 'mirrors repo2' do
          FakeFS.with_fresh do
            FileUtils.mkdir_p path
            File.write("#{path}/repos.json", repo_settings.to_json)

            expect { command }.to output(/Mirroring repository #{repo2.name}/).to_stdout.and output('').to_stderr
          end
        end
      end

      context 'with exceptions during mirroring' do
        let(:mirror_error_double) { instance_double 'RMT::Mirror' }

        before do
          expect(mirror_error_double).to receive(:mirror).once.and_raise(RMT::Mirror::Exception, 'black mirror')
          expect(mirror_double).to receive(:mirror).once
          expect(RMT::Mirror).to receive(:from_repo_model).with(repo1, base_dir: RMT::DEFAULT_MIRROR_DIR, deduplication_enabled: false).and_return(mirror_error_double)
          expect(RMT::Mirror).to receive(:from_repo_model).with(repo2, base_dir: RMT::DEFAULT_MIRROR_DIR, deduplication_enabled: false).and_return(mirror_double)
        end

        it 'tries to mirror repo1' do
          FakeFS.with_fresh do
            FileUtils.mkdir_p path
            File.write("#{path}/repos.json", repo_settings.to_json)

            expect { command }.to output("black mirror\n").to_stderr.and output(/Mirroring repository #{repo1.name}/).to_stdout
          end
        end
        it 'tries to mirror repo2' do
          FakeFS.with_fresh do
            FileUtils.mkdir_p path
            File.write("#{path}/repos.json", repo_settings.to_json)

            expect { command }.to output("black mirror\n").to_stderr.and output(/Mirroring repository #{repo2.name}/).to_stdout
          end
        end
      end
    end
  end
end
