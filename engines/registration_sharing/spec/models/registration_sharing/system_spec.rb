require 'rails_helper'

describe System, type: :model do
  let(:system) { FactoryGirl.build(:registration_sharing_system) }

  it 'triggers after_commit callback' do
    expect(system).to receive(:share_registration)
    system.save!
  end

  it 'does not trigger registration sharing' do
    expect(RegistrationSharing).not_to receive(:share)
    system.save!
  end
end
