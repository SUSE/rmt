require 'rails_helper'

RSpec.describe RMT::RepoManager do
  describe '#execute!' do
    before do
      described_class.new(argv).execute!
      repository.reload
    end

    describe 'enable' do
      subject(:repository) { FactoryGirl.create :repository, :with_products }

      context 'without parameters' do
        let(:argv) { [] }

        its(:mirroring_enabled) { is_expected.to be(false) }
      end

      context 'by repo id' do
        let(:argv) { ['-e', '-r', repository.id.to_s] }

        its(:mirroring_enabled) { is_expected.to be(true) }
      end

      context 'by product without arch' do
        let(:product) { repository.services.first.product }
        let(:argv) { ['-e', '-p', "#{product.identifier}/#{product.version}"] }

        its(:mirroring_enabled) { is_expected.to be(true) }
      end

      context 'by product with arch' do
        let(:product) { repository.services.first.product }
        let(:argv) { ['-e', '-p', "#{product.identifier}/#{product.version}/#{product.arch}"] }

        its(:mirroring_enabled) { is_expected.to be(true) }
      end
    end

    describe 'disable' do
      subject(:repository) { FactoryGirl.create :repository, :with_products, :mirroring_enabled }

      context 'without parameters' do
        let(:argv) { [] }

        its(:mirroring_enabled) { is_expected.to be(true) }
      end

      context 'by repo id' do
        let(:argv) { ['-d', '-r', repository.id.to_s] }

        its(:mirroring_enabled) { is_expected.to be(false) }
      end

      context 'by product without arch' do
        let(:product) { repository.services.first.product }
        let(:argv) { ['-d', '-p', "#{product.identifier}/#{product.version}"] }

        its(:mirroring_enabled) { is_expected.to be(false) }
      end

      context 'by product with arch' do
        let(:product) { repository.services.first.product }
        let(:argv) { ['-d', '-p', "#{product.identifier}/#{product.version}/#{product.arch}"] }

        its(:mirroring_enabled) { is_expected.to be(false) }
      end
    end
  end
end
