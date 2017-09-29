require 'rails_helper'

RSpec.describe RMT::CLI::Mirror do
  include_context 'console output'

  describe '#mirror' do
    context 'without repositories marked for mirroring' do
      before do
        FactoryGirl.create :repository, :with_products, mirroring_enabled: false
        expect_any_instance_of(RMT::Mirror).not_to receive(:mirror)
        described_class.mirror
      end

      it 'stdout is empty' do
        expect(stdout.string).to be_empty
      end

      it 'stdout contains warning' do
        expect(stderr.string).to eq("There are no repositories marked for mirroring.\n")
      end
    end

    context 'with repositories marked for mirroring' do
      let!(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }

      before do
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once) do
          puts 'Test double'
        end
        described_class.mirror
        repository.reload
      end

      it 'stdout is empty' do
        expect(stdout.string).to eq("Test double\n")
      end

      it 'stdout contains warning' do
        expect(stderr.string).to be_empty
      end

      it 'updates repository mirroring timestamp' do
        expect(repository.last_mirrored_at).not_to be_nil
      end
    end

    context 'with exceptions during mirroring' do
      before do
        FactoryGirl.create :repository, :with_products, mirroring_enabled: true
        expect_any_instance_of(RMT::Mirror).to receive(:mirror).at_least(:once) do
          raise RMT::Mirror::Exception, 'Test double exception'
        end
        described_class.mirror
      end

      it 'stdout is empty' do
        expect(stdout.string).to be_empty
      end

      it 'stdout contains warning' do
        expect(stderr.string).to eq("Test double exception\n")
      end
    end
  end
end
