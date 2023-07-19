require 'rails_helper'

RSpec.describe System, type: :model do
  subject { system }

  let(:system) { FactoryBot.create(:system, :with_activated_base_product) }
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

  describe 'validation' do
    it { is_expected.to validate_uniqueness_of(:system_token).scoped_to(:login, :password).case_insensitive }
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

    context 'when scc_system_id is set' do
      before do
        DeregisteredSystem.where(scc_system_id: 9000).delete_all
        system.update_column(:scc_system_id, 9000)
      end

      it 'scc_synced_at is not null before update' do
        system.destroy
        expect(DeregisteredSystem.find_by(scc_system_id: 9000)).not_to be(nil)
      end
    end
  end

  describe 'when system is updated' do
    before do
      system.update_column(:scc_synced_at, Time.zone.now)
    end

    it 'scc_synced_at is not null before update' do
      system.reload
      expect(system.scc_synced_at).not_to be(nil)
    end

    it 'scc_synced_at is null after update' do
      system.updated_at = Time.zone.now
      system.save!
      system.reload
      expect(system.scc_synced_at).to be(nil)
    end
  end

  it 'assigns nil system_token on create' do
    system = described_class.create(login: 'abc', password: 'xyz')
    expect(system.system_token).to be_nil
  end

  describe '#get_by_credentials' do
    subject { described_class.get_by_credentials(login, password) }

    let(:login) { 'system_abcd' }
    let(:password) { 'password1234' }

    context 'when there are no systems with the given credentials' do
      let(:system) { nil }

      it { is_expected.to be_kind_of(ActiveRecord::Relation) }
      it { is_expected.to be_empty }
    end

    context 'when there are only one system with the given credentials' do
      before { create(:system, login: login, password: password) }

      it { is_expected.to be_kind_of(ActiveRecord::Relation) }
      it { is_expected.to have_attributes(count: 1) }
      it { is_expected.to all(have_attributes(class: described_class, login: login, password: password)) }
    end

    context 'when there are more than one system with the given credentials' do
      before { create_list(:system, 5, :with_system_token, login: login, password: password) }

      it { is_expected.to be_kind_of(ActiveRecord::Relation) }
      it { is_expected.to have_attributes(count: 5) }
      it { is_expected.to all(have_attributes(class: described_class, login: login, password: password)) }
    end
  end

  describe '#cloud_provider' do
    subject { system.cloud_provider }

    before do
      system.system_information = information.to_json
      system.save
    end

    context 'cloud provider information is available' do
      let(:information) { { cloud_provider: 'Amazon' } }

      it { is_expected.not_to be_nil }
      it { is_expected.to eq('Amazon') }
    end

    context 'cloud provider information is not available' do
      let(:information) { {} }

      it { is_expected.to be_nil }
    end
  end
end
