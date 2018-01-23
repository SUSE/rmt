require 'rails_helper'

RSpec.describe Product, type: :model do
  it { is_expected.to have_one :service }
  it { is_expected.to have_many :repositories }
  it { is_expected.to have_many :bases }
  it { is_expected.to have_many :extensions }

  describe '#has_extension?' do
    subject { product.has_extension? }

    let(:product) { create :product }


    context 'when has no extensions' do
      it { is_expected.to eq false }
    end

    context 'when has extension' do
      before { create(:product, :extension, base_products: [product]) }
      it { is_expected.to eq true }
    end
  end

  describe '#mirror?' do
    subject { product.mirror? }

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

  describe '#extensions' do
    let(:base_a) { FactoryGirl.create(:product) }
    let(:base_b) { FactoryGirl.create(:product) }

    let(:level_one_extension) { FactoryGirl.create(:product, :extension, base_products: [base_a, base_b]) }

    let!(:level_two_extension_a) { FactoryGirl.create(:product, :extension, base_products: [level_one_extension], root_product: base_a) }
    let!(:level_two_extension_b) { FactoryGirl.create(:product, :extension, base_products: [level_one_extension], root_product: base_b) }

    it 'returns correct extensions for base A' do
      expect(level_one_extension.extensions.for_root_product(base_a)).to eq([level_two_extension_a])
    end

    it 'returns correct extensions for base B' do
      expect(level_one_extension.extensions.for_root_product(base_b)).to eq([level_two_extension_b])
    end
  end

  describe '#mirrored_extensions' do
    let(:base_a) { FactoryGirl.create(:product) }
    let(:base_b) { FactoryGirl.create(:product) }

    let(:level_one_extension) { FactoryGirl.create(:product, :extension, base_products: [base_a, base_b]) }

    let(:level_two_extension_a_not_mirrored) { FactoryGirl.create(:product, :extension, base_products: [level_one_extension], root_product: base_a) }
    let(:level_two_extension_b_not_mirrored) { FactoryGirl.create(:product, :extension, base_products: [level_one_extension], root_product: base_b) }

    let(:level_two_extension_a_mirrored) do
      FactoryGirl.create(:product, :extension, :with_mirrored_repositories, base_products: [level_one_extension], root_product: base_a)
    end
    let(:level_two_extension_b_mirrored) do
      FactoryGirl.create(:product, :extension, :with_mirrored_repositories, base_products: [level_one_extension], root_product: base_b)
    end

    before do
      level_two_extension_a_not_mirrored
      level_two_extension_b_not_mirrored
      level_two_extension_a_mirrored
      level_two_extension_b_mirrored
    end

    it 'returns correct extensions for base A' do
      expect(level_one_extension.mirrored_extensions.for_root_product(base_a)).to eq([level_two_extension_a_mirrored])
    end

    it 'returns correct extensions for base B' do
      expect(level_one_extension.mirrored_extensions.for_root_product(base_b)).to eq([level_two_extension_b_mirrored])
    end
  end

  describe '#recommended_for?' do
    let!(:base_a) { FactoryGirl.create(:product) }
    let!(:base_b) { FactoryGirl.create(:product) }

    it 'recommended for base product A' do
      extension = FactoryGirl.create(:product, :extension, base_products: [base_a], recommended: true)
      expect(extension.recommended_for?(base_a)).to be(true)
    end

    it 'not recommended for base product A' do
      extension = FactoryGirl.create(:product, :extension, base_products: [base_a], recommended: false)
      expect(extension.recommended_for?(base_a)).to be(false)
    end

    it 'not recommended for unrelated product B' do
      extension = FactoryGirl.create(:product, :extension, base_products: [base_a], recommended: true)
      expect(extension.recommended_for?(base_b)).to be(false)
    end
  end
end
