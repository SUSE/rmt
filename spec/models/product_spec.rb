require 'rails_helper'

RSpec.describe Product, type: :model do
  subject { create :product }

  let(:extension) { create :product }

  it { should have_one :service }
  it { should have_many :repositories }
  it { should have_many :bases }
  it { should have_many :extensions }

  context 'when has no extensions' do
    its(:has_extension?) { is_expected.to eq false }
  end

  context 'when has extension' do
    before { subject.extensions << extension }
    its(:has_extension?) { is_expected.to eq true }
  end
end
