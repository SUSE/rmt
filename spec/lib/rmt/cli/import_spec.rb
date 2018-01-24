require 'rails_helper'

# rubocop:disable RSpec/MultipleExpectations
# rubocop:disable RSpec/NestedGroups

describe RMT::CLI::Import do
  let(:path) {'/mnt/usb'}

  describe 'scc-data' do
    include_examples 'handles non-existing path'

    subject(:command) {described_class.start(['scc-data', path])}

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

    subject(:command) {described_class.start(['repos', path])}

    let(:repo_settings) do
      [
          {url: 'http://foo.bar/repo1', auth_token: 'foobar'},
          {url: 'http://foo.bar/repo2', auth_token: ''}
      ]
    end
    let(:mirror_double) {instance_double 'RMT::Mirror'}

    context 'with repos marked for mirroring' do
      let!(:repo) {create :repository, mirroring_enabled: true}

      it 'triggers mirroring' do
        FakeFS.with_fresh do
          FileUtils.mkdir_p path

          expect(mirror_double).to receive(:mirror)
          expect(RMT::Mirror).to receive(:from_repo_model).with(repo, base_dir: RMT::DEFAULT_MIRROR_DIR).and_return(mirror_double)
          expect {command}.to output(/Mirroring repository #{repo.name}/).to_stdout
        end
      end

      context 'with exceptions during mirroring' do
        it 'outputs exception message' do
          FakeFS.with_fresh do
            FileUtils.mkdir_p path

            expect(mirror_double).to receive(:mirror).and_raise(RMT::Mirror::Exception, 'black mirror')
            expect(RMT::Mirror).to receive(:from_repo_model).and_return(mirror_double)
            expect {command}.to output("black mirror\n").to_stderr.and output(/Mirroring repository #{repo.name}/).to_stdout
          end
        end
      end
    end
  end
end
