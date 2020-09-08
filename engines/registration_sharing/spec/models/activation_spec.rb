require 'rails_helper'

describe Activation, type: :model do
  context 'when the model is created' do
    let(:system) { FactoryBot.build(:system) }
    let(:activation) { FactoryBot.build(:activation, system: system) }

    it 'triggers after_commit callback' do
      expect(system).to receive(:share_registration)
      expect(activation).to receive(:share_registration)
      activation.save!
    end

    it 'triggers registration sharing' do
      expect(system).to receive(:share_registration)
      expect(RegistrationSharing).to receive(:called_from_regsharing?).and_return(false)
      expect(RegistrationSharing).to receive(:save_for_sharing).with(activation)
      activation.save!
    end
  end

  context 'when the model is updated' do
    let(:system) { FactoryBot.create(:system) }
    let(:activation) { FactoryBot.create(:activation, system: system) }

    it 'activation does not trigger after_commit callback' do
      expect(activation).not_to receive(:share_registration)
      activation.updated_at = Time.new(2000).utc
      activation.save!
    end

    it 'system does not trigger after_commit callback' do
      expect(system).not_to receive(:share_registration)
      system.updated_at = Time.new(2000).utc
      system.save!
    end
  end

  context 'when the model is destroyed' do
    let(:system) { FactoryBot.create(:system) }
    let(:activation) { FactoryBot.create(:activation, system: system) }

    it 'activation triggers after_commit callback' do
      expect(activation).to receive(:share_registration)
      activation.destroy
    end

    it 'system triggers after_commit callback' do
      expect(system).to receive(:share_registration)
      system.destroy
    end
  end
end
