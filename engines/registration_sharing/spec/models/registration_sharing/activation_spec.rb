require 'rails_helper'

describe Activation, type: :model do
  let(:system) { FactoryGirl.build(:registration_sharing_system) }
  let(:activation) { FactoryGirl.build(:registration_sharing_activation, system: system) }

  it 'triggers after_commit callback' do
    expect(system).to receive(:share_registration)
    expect(activation).to receive(:share_registration)
    activation.save!
  end

  it 'triggers registration sharing' do
    expect(system).to receive(:share_registration)
    expect(activation).to receive(:share_registration)
    expect(RegistrationSharing).not_to receive(:save_for_sharing)
    activation.save!
  end
end
