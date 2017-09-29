require 'rails_helper'

# rubocop:disable RSpec/NestedGroups

RSpec.describe RMT::CLI::Repos do
  include_context 'console output'

  describe '#enable' do
    before do
      described_class.start(argv)
      repository.reload
    end

    subject(:repository) { FactoryGirl.create :repository, :with_products }

    context 'without parameters' do
      let(:argv) { [] }

      its(:mirroring_enabled) { is_expected.to be(false) }
      it 'outputs list of commands' do
        expect(stdout.string).to match(/Commands:/)
      end
    end

    context 'by repo id' do
      let(:argv) { ['enable', repository.id.to_s] }

      its(:mirroring_enabled) { is_expected.to be(true) }
      it 'outputs success message' do
        expect(stdout.string).to eq("Repository successfully enabled.\n")
      end
    end

    context 'by product without arch' do
      let(:product) { repository.services.first.product }
      let(:argv) { ['enable', "#{product.identifier}/#{product.version}"] }

      its(:mirroring_enabled) { is_expected.to be(true) }
      it 'outputs success message' do
        expect(stdout.string).to eq("1 repo(s) successfully enabled.\n")
      end
    end

    context 'by product with arch' do
      let(:product) { repository.services.first.product }
      let(:argv) { ['enable', "#{product.identifier}/#{product.version}/#{product.arch}"] }

      its(:mirroring_enabled) { is_expected.to be(true) }
      it 'outputs success message' do
        expect(stdout.string).to eq("1 repo(s) successfully enabled.\n")
      end
    end
  end

  describe '#disable' do
    before do
      described_class.start(argv)
      repository.reload
    end

    subject(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }

    context 'without parameters' do
      let(:argv) { [] }

      its(:mirroring_enabled) { is_expected.to be(true) }
      it 'outputs commands' do
        expect(stdout.string).to match(/Commands:/)
      end
    end

    context 'by repo id' do
      let(:argv) { ['disable', repository.id.to_s] }

      its(:mirroring_enabled) { is_expected.to be(false) }
      it 'outputs success message' do
        expect(stdout.string).to eq("Repository successfully disabled.\n")
      end
    end

    context 'by product without arch' do
      let(:product) { repository.services.first.product }
      let(:argv) { ['disable', "#{product.identifier}/#{product.version}"] }

      its(:mirroring_enabled) { is_expected.to be(false) }
      it 'outputs success message' do
        expect(stdout.string).to eq("1 repo(s) successfully disabled.\n")
      end
    end

    context 'by product with arch' do
      let(:product) { repository.services.first.product }
      let(:argv) { ['disable', "#{product.identifier}/#{product.version}/#{product.arch}"] }

      its(:mirroring_enabled) { is_expected.to be(false) }
      it 'outputs success message' do
        expect(stdout.string).to eq("1 repo(s) successfully disabled.\n")
      end
    end
  end

  describe '#list' do
    context 'without enabled repositories' do
      let(:argv) { ['list'] }

      before do
        described_class.start(argv)
      end

      it 'outputs success message' do
        expect(stderr.string).to eq("No repositories enabled.\n")
      end
    end

    context 'with enabled repositories' do
      let!(:repository_one) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }
      let!(:repository_two) { FactoryGirl.create :repository, :with_products, mirroring_enabled: false }

      before do
        described_class.start(argv)
      end

      context 'without parameters' do
        let(:argv) { ['list'] }
        let(:expected_output) do
          rows = []
          rows << [
            repository_one.id,
            repository_one.name,
            repository_one.description,
            repository_one.enabled,
            repository_one.mirroring_enabled,
            repository_one.last_mirrored_at
          ]
          Terminal::Table.new(
            headings: ['ID', 'Name', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored'],
            rows: rows
          ).to_s + "\n"
        end

        it 'outputs success message' do
          expect(stdout.string).to eq(expected_output)
        end
      end

      context 'list all' do
        let(:argv) { [ 'list', '--all' ] }
        let(:expected_output) do
          rows = []
          rows << [
            repository_one.id,
            repository_one.name,
            repository_one.description,
            repository_one.enabled,
            repository_one.mirroring_enabled,
            repository_one.last_mirrored_at
          ]
          rows << [
            repository_two.id,
            repository_two.name,
            repository_two.description,
            repository_two.enabled,
            repository_two.mirroring_enabled,
            repository_two.last_mirrored_at
          ]
          Terminal::Table.new(
            headings: ['ID', 'Name', 'Description', 'Mandatory?', 'Mirror?', 'Last mirrored'],
            rows: rows
          ).to_s + "\n"
        end

        it 'outputs success message' do
          expect(stdout.string).to eq(expected_output)
        end
      end
    end
  end
end
