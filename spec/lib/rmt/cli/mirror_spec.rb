require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe RMT::CLI::Mirror do
  describe '#mirror' do
    context 'without repositories marked for mirroring' do
      subject(:command) do
        repository
        expect_any_instance_of(RMT::Mirror).not_to receive(:mirror)
        described_class.new.repos
      end

      let(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: false }

      it 'stdout contains warning' do
        expect { command }.to output("There are no repositories marked for mirroring.\n").to_stderr.and output('').to_stdout
      end
    end

    context 'with repositories marked for mirroring' do
      let!(:repository) { create :repository, :with_products, mirroring_enabled: true }

      context do
        subject(:command) do
          expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once) do
            puts 'Test double'
          end
          described_class.new.repos
          repository.reload
        end

        it 'outputs mirroring progress' do
          expect { command }.to output(/Mirroring repository #{repository.name}/).to_stdout.and output('').to_stderr
        end
      end

      context do
        before do
          expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once)
          allow(STDOUT).to receive(:puts)
          described_class.new.repos
          repository.reload
        end

        it 'updates repository mirroring timestamp' do
          expect(repository.last_mirrored_at).not_to be_nil
        end
      end

      context 'with exceptions during mirroring' do
        subject(:command) do
          expect_any_instance_of(RMT::Mirror).to receive(:mirror).and_raise(RMT::Mirror::Exception, 'black mirror')
          described_class.new.repos
        end

        it 'outputs exception message' do
          expect { command }.to output("black mirror\n").to_stderr
        end
      end
    end
  end
end
