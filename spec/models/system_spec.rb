require 'rails_helper'

RSpec.describe System, type: :model do
  let(:system) { create :system_with_activated_base_product }

  subject { system }

  it { should have_many :activations }
  it { should have_many(:services).through(:activations) }
  it { should have_many(:repositories).through(:services) }

  let(:login) { described_class.generate_secure_login }
  let(:password) { described_class.generate_secure_password }

  describe 'login' do
    subject { login }

    it { is_expected.to include 'SCC_' }
    its(:length) { is_expected.to eq 36 }
  end

  describe 'password' do
    subject { password }

    its(:length) { is_expected.to eq 16 }
  end

  context 'when system is deleted' do
    let(:activation) do
      activation = create(:activation)
      activation.system.destroy
    end

    it 'activation is also deleted' do
      expect { activation.reload }.to raise_error ActiveRecord::RecordNotFound
    end
  end
end
