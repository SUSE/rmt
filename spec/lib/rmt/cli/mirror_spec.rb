require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

describe RMT::CLI::Mirror do
  describe '#repos' do
    subject(:command) { described_class.new.repos }

    context 'without repositories marked for mirroring' do
      before { create :repository, :with_products, mirroring_enabled: false }

      it 'outputs a warning' do
        expect_any_instance_of(RMT::Mirror).not_to receive(:mirror)
        expect { command }.to output("There are no repositories marked for mirroring.\n").to_stderr.and output('').to_stdout
      end
    end

    context 'with repositories marked for mirroring' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }

      before { expect_any_instance_of(RMT::Mirror).to receive(:mirror) }

      it 'outputs mirroring progress' do
        expect { command }.to output(/Mirroring repository #{repository.name}/).to_stdout.and output('').to_stderr
      end

      it 'updates repository mirroring timestamp' do
        Timecop.freeze(Time.utc(2018)) do
          expect { command }.to change { repository.reload.last_mirrored_at }.to(DateTime.now.utc)
                                  .and output(/Mirroring repository #{repository.name}/).to_stdout
        end
      end

      context 'with exceptions during mirroring' do
        before { allow_any_instance_of(RMT::Mirror).to receive(:mirror).and_raise(RMT::Mirror::Exception, 'black mirror') }

        it 'outputs exception message' do
          expect { command }.to output("black mirror\n").to_stderr.and output(/Mirroring repository #{repository.name}/).to_stdout
        end
      end
    end
  end

  describe '#custom' do
    # TODO: These "specs" for the `mirror custom` command are only placeholders, as is the feature itself.
    #       It will be changed soon to also store these custom repos in the database.
    #       So, in the the end, we will most likely not even have the `mirror custom` command in its current form anymore.

    subject(:command) { described_class.new.custom(url) }

    let(:url) { 'http://example.org/' }
    let(:mirror_double) { instance_double(RMT::Mirror) }

    it 'triggers mirroring of a custom repo' do # rubocop:disable RSpec/MultipleExpectations
      expect(RMT::Mirror).to receive(:new).with(hash_including(repository_url: url)).and_return mirror_double
      expect(mirror_double).to receive(:mirror)
      command
    end

    context 'with an URL which is not really an URL' do
      it 'does not die with a stacktrace'
    end

    context 'with an URL which is not a repo' do
      it 'does not die with a stacktrace'
    end

    context 'with an optional PATH' do
      it 'mirrors custom repo into that path'
    end
  end
end
