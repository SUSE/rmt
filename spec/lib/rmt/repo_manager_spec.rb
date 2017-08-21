require 'rails_helper'

RSpec.describe RMT::RepoManager do
  describe '#execute!' do
    before do
      # disable output to stdout while running specs
      allow(STDOUT).to receive(:puts)
      allow(STDOUT).to receive(:print)

      described_class.start(argv)
      repository.reload
    end

    describe 'enable' do
      subject(:repository) { FactoryGirl.create :repository, :with_products }

      context 'without parameters' do
        let(:argv) { [] }

        its(:mirroring_enabled) { is_expected.to be(false) }
      end

      context 'by repo id' do
        let(:argv) { ['enable', repository.id.to_s] }

        its(:mirroring_enabled) { is_expected.to be(true) }
      end

      context 'by product without arch' do
        let(:product) { repository.services.first.product }
        let(:argv) { ['enable', "#{product.identifier}/#{product.version}"] }

        its(:mirroring_enabled) { is_expected.to be(true) }
      end

      context 'by product with arch' do
        let(:product) { repository.services.first.product }
        let(:argv) { ['enable', "#{product.identifier}/#{product.version}/#{product.arch}"] }

        its(:mirroring_enabled) { is_expected.to be(true) }
      end
    end

    describe 'disable' do
      subject(:repository) { FactoryGirl.create :repository, :with_products, mirroring_enabled: true }

      context 'without parameters' do
        let(:argv) { [] }

        its(:mirroring_enabled) { is_expected.to be(true) }
      end

      context 'by repo id' do
        let(:argv) { ['disable', repository.id.to_s] }

        its(:mirroring_enabled) { is_expected.to be(false) }
      end

      context 'by product without arch' do
        let(:product) { repository.services.first.product }
        let(:argv) { ['disable', "#{product.identifier}/#{product.version}"] }

        its(:mirroring_enabled) { is_expected.to be(false) }
      end

      context 'by product with arch' do
        let(:product) { repository.services.first.product }
        let(:argv) { ['disable', "#{product.identifier}/#{product.version}/#{product.arch}"] }

        its(:mirroring_enabled) { is_expected.to be(false) }
      end
    end
  end
end
