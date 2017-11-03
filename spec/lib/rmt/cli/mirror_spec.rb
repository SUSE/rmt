require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe RMT::CLI::Mirror do
  describe '#mirror' do
    context 'without repositories marked for mirroring' do
      subject(:command) do
        repository
        expect_any_instance_of(RMT::Mirror).not_to receive(:mirror)
        described_class.mirror
      end

      let(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: false }

      it 'stdout contains warning' do
        expect { command }.to output("There are no repositories marked for mirroring.\n").to_stderr.and output('').to_stdout
      end
    end

    context 'repositories marked for mirroring' do
      let(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }

      context do
        subject(:command) do
          repository
          expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once) do
            puts 'Test double'
          end
          described_class.mirror
          repository.reload
        end

        it 'outputs mirroring progress' do
          expect { command }.to output("Mirroring repository #{repository.name}\nTest double\n").to_stdout.and output('').to_stderr
        end
      end

      context do
        before do
          repository
          expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once)
          allow(STDOUT).to receive(:puts)
          described_class.mirror
          repository.reload
        end

        it 'updates repository mirroring timestamp' do
          expect(repository.last_mirrored_at).not_to be_nil
        end
      end
    end

    context 'with exceptions during mirroring' do
      subject(:command) do
        repository
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once) do
          raise RMT::Mirror::Exception, 'Test double exception'
        end
        described_class.mirror
      end

      let(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }

      it 'outputs exception message' do
        expect { command }.to output("Mirroring repository #{repository.name}\n").to_stdout.and output("Test double exception\n").to_stderr
      end
    end

    context 'with Interrupt during mirroring' do
      subject(:command) do
        repository
        allow(STDOUT).to receive(:puts)
        expect(described_class).to receive(:mirror_one_repo).at_least(:once) do
          raise Interrupt
        end
        described_class.mirror
      end

      let(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }

      it 'raises RMT::CLI::Error' do
        expect { command }.to raise_error(RMT::CLI::Error, 'Interrupted.')
      end
    end
  end
end
