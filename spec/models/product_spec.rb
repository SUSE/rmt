require 'rails_helper'

RSpec.describe Product, type: :model do
  it { is_expected.to have_one :service }
  it { is_expected.to have_many :repositories }
  it { is_expected.to have_many :bases }
  it { is_expected.to have_many :extensions }

  describe '#has_extension?' do
    subject { product.has_extension? }

    let(:product) { create :product }
    let(:extension) { create :product }

    context 'when has no extensions' do
      it { is_expected.to eq false }
    end

    context 'when has extension' do
      before { product.extensions << extension }
      it { is_expected.to eq true }
    end
  end

  describe 'published' do
    before do
      create :product, release_stage: 'released'
      create :product, release_stage: 'beta'
    end

    subject { Product.published.count }

    it { is_expected.to eq 1 }
  end

  describe '#is_mirrored' do
    subject { product.is_mirrored }

    context 'without any repositories' do
      let(:product) { create :product }

      it { is_expected.to be true }
    end

    context 'with_not_mirrored_repositories' do
      let(:product) { create :product, :with_not_mirrored_repositories }

      it { is_expected.to be false }
    end

    context 'with_mirrored_repositories' do
      let(:product) { create :product, :with_mirrored_repositories }

      it { is_expected.to be true }
    end
  end

  describe '.clean_up_version' do
    subject { described_class.clean_up_version(version) }

    context 'without special symbols' do
      let(:version) { '42' }

      it { is_expected.to eq('42') }
    end

    context 'with a dot' do
      let(:version) { '42.0' }

      it { is_expected.to eq('42') }
    end

    context 'with dashes' do
      let(:version) { '42-0' }

      it { is_expected.to eq('42') }
    end
  end
end
