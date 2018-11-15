require 'rails_helper'

describe System, type: :model do
  let(:system) { FactoryGirl.build(:system) }

  it 'triggers after_commit callback' do
    expect(system).to receive(:share_registration)
    system.save!
  end

  it 'triggers registration sharing' do
    expect(RegistrationSharing).to receive(:share).with(system)
    system.save!
  end
end
