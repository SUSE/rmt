require 'rails_helper'

RSpec.describe System, type: :model do
  subject { system }

  let(:system) { FactoryGirl.create(:system, :with_activated_base_product) }
  let(:login) { described_class.generate_secure_login }
  let(:password) { described_class.generate_secure_password }

  it { is_expected.to have_many(:activations).dependent(:destroy) }
  it { is_expected.to have_many(:services).through(:activations) }
  it { is_expected.to have_many(:repositories).through(:services) }

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
    context 'activation' do
      let(:activation) do
        activation = create(:activation)
        activation.system.destroy
      end


      it 'activation is also deleted' do
        expect { activation.reload }.to raise_error ActiveRecord::RecordNotFound
      end
    end

    context 'hw_info' do
      let(:hw_info) do
        hw_info = create(:system, :with_hw_info).hw_info
        hw_info.system.destroy
      end

      it 'hw_info is also deleted' do
        expect { hw_info.reload }.to raise_error ActiveRecord::RecordNotFound
      end
    end
  end
end
