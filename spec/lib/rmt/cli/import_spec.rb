require 'rails_helper'

describe RMT::CLI::Import do
  let(:path) { '/mnt/usb' }

  describe 'data' do
    include_examples 'handles non-existing path'

    let(:command) { described_class.start(['data', path]) }

    it 'calls sync with special params' do
      FakeFS.with_fresh do
        FileUtils.mkdir_p path

        expect_any_instance_of(RMT::SCC).to receive(:import).with(path)
        command
      end
    end
  end

  describe 'repos' do
    include_examples 'handles non-existing path'

    let(:command) { described_class.start(['repos', path]) }

    context 'with no repos marked for mirroring' do
      it 'complains and exits' do
        FakeFS.with_fresh do
          FileUtils.mkdir_p path

          expect { command }.to output("There are no repositories marked for mirroring.\n").to_stderr
        end
      end
    end

    context 'with repos marked for mirroring' do
      let(:repo) { create :repository, mirroring_enabled: true }
      let(:mirror_double) { instance_double 'RMT::Mirror' }

      it 'triggers mirroring' do
        FakeFS.with_fresh do
          FileUtils.mkdir_p path

          expect(mirror_double).to receive(:mirror)
          expect(RMT::Mirror).to receive(:from_repo_model).with(repo).and_return(mirror_double)
          command
        end
      end
    end
  end
end
