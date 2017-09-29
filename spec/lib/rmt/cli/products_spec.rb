require 'rails_helper'

RSpec.describe RMT::CLI::Products do
  include_context 'console output'

  describe '#list' do
    let(:argv) { ['list'] }

    context 'with empty database' do
      before do
        described_class.start(argv)
      end

      it 'stdout is empty' do
        expect(stdout.string).to be_empty
      end

      it 'stderr contains warning' do
        expect(stderr.string).to eq("No products found in the DB. Please run \"rmt-cli scc sync\" to synchronize with SUSE Customer Center first.\n")
      end
    end

    context 'with products' do
      let!(:product) { FactoryGirl.create :product, :with_mirrored_repositories }
      let(:expected_output) do
        rows = []
        rows << [
          product.id,
          product.name,
          product.version,
          product.arch,
          product.product_string,
          product.release_stage,
          product.mirror?,
          product.last_mirrored_at
        ]
        Terminal::Table.new(
          headings: ['ID', 'Name', 'Version', 'Architecture', 'Product string', 'Release stage', 'Mirror?', 'Last mirrored'],
          rows: rows
        ).to_s + "\n"
      end

      before do
        described_class.start(argv)
      end

      it 'stdout contains products table' do
        expect(stdout.string).to eq(expected_output)
      end

      it 'stderr is empty' do
        expect(stderr.string).to be_empty
      end
    end
  end

  describe '#enable' do
    let(:product) { FactoryGirl.create :product, :with_not_mirrored_repositories }

    before do
      described_class.start(argv)
    end

    context 'by product ID' do
      let(:argv) { ['enable', product.id.to_s] }

      it 'enables the mandatory product repositories' do
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(repository.enabled)
        end
      end

      it 'stdout contains success message' do
        expect(stdout.string).to eq("#{product.repositories.where(enabled: true).count} repo(s) successfully enabled.\n")
      end

      it 'stderr is empty' do
        expect(stderr.string).to be_empty
      end
    end

    context 'by product string' do
      let(:argv) { ['enable', product.product_string] }

      it 'enables the mandatory product repositories' do
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(repository.enabled)
        end
      end

      it 'stdout contains success message' do
        expect(stdout.string).to eq("#{product.repositories.where(enabled: true).count} repo(s) successfully enabled.\n")
      end

      it 'stderr is empty' do
        expect(stderr.string).to be_empty
      end
    end
  end

  describe '#disable' do
    let(:product) { FactoryGirl.create :product, :with_mirrored_repositories }

    before do
      described_class.start(argv)
    end

    context 'by product ID' do
      let(:argv) { ['disable', product.id.to_s] }

      it 'enables the mandatory product repositories' do
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(false)
        end
      end

      it 'stdout contains success message' do
        expect(stdout.string).to eq("#{product.repositories.count} repo(s) successfully disabled.\n")
      end

      it 'stderr is empty' do
        expect(stderr.string).to be_empty
      end
    end

    context 'by product string' do
      let(:argv) { ['disable', product.product_string] }

      it 'enables the mandatory product repositories' do
        product.repositories.each do |repository|
          expect(repository.mirroring_enabled).to eq(false)
        end
      end

      it 'stdout contains success message' do
        expect(stdout.string).to eq("#{product.repositories.count} repo(s) successfully disabled.\n")
      end

      it 'stderr is empty' do
        expect(stderr.string).to be_empty
      end
    end
  end
end
