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
end
