require 'rails_helper'

RSpec.describe Activation, type: :model do
  describe 'relations and validations' do
    it { is_expected.to belong_to :service }
    it { is_expected.to belong_to :system }
    it { is_expected.to have_one :product }

    it { is_expected.to validate_presence_of(:system) }
    it { is_expected.to validate_presence_of(:service) }

    it { is_expected.to have_db_column(:system_id).of_type(:integer).with_options(null: false) }
    it { is_expected.to have_db_column(:service_id).of_type(:integer).with_options(null: false) }

    subject(:activation) { FactoryGirl.create :activation, system_id: system.id }

    let(:system) { FactoryGirl.create :system }
  end

  describe 'system.scc_registered_at hooks' do
    context 'when an activation is created' do
      let!(:system) { FactoryGirl.create :system, scc_registered_at: Time.zone.now }

      it 'system.scc_registered_at is not nil before activation is created' do
        expect(system.scc_registered_at).not_to be(nil)
      end

      it 'system.scc_registered_at is nil after activation is created' do
        FactoryGirl.create :activation, system_id: system.id
        system.reload
        expect(system.scc_registered_at).to be(nil)
      end
    end

    context 'when an activation is destroyed' do
      let(:system) { FactoryGirl.create :system }
      let!(:activation) do
        activation = FactoryGirl.create :activation, system_id: system.id
        system.update_column(:scc_registered_at, Time.zone.now)
        activation.system.reload
        activation
      end

      it 'system.scc_registered_at is not nil before activation is destroyed' do
        expect(system.scc_registered_at).not_to be(nil)
      end

      it 'system.scc_registered_at is nil after activation is destroyed' do
        activation.destroy!
        system.reload
        expect(system.scc_registered_at).to be(nil)
      end
    end

    context 'when an activation is updated' do
      let(:system) { FactoryGirl.create :system }
      let!(:activation) do
        activation = FactoryGirl.create :activation, system_id: system.id
        system.update_column(:scc_registered_at, Time.zone.now)
        activation.system.reload
        activation
      end

      it 'system.scc_registered_at is not nil before activation is updated' do
        expect(system.scc_registered_at).not_to be(nil)
      end

      it 'system.scc_registered_at is nil after activation is updated' do
        activation.updated_at = Time.zone.now
        activation.save!
        system.reload
        expect(system.scc_registered_at).to be(nil)
      end
    end
  end
end
