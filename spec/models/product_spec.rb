require 'rails_helper'

RSpec.describe Product, type: :model do
  it { should have_one :service }
  it { should have_many :repositories }
  it { should have_many :bases }
  it { should have_many :extensions }

  describe '#has_extension?' do
    let(:product) { create :product }
    let(:extension) { create :product }

    subject { product.has_extension? }

    context 'when has no extensions' do
      it { is_expected.to eq false }
    end

    context 'when has extension' do
      before { product.extensions << extension }
      it { is_expected.to eq true }
    end
  end
end
