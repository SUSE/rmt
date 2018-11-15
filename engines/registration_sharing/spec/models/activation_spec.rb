require 'rails_helper'

describe Activation, type: :model do
  let(:system) { FactoryGirl.build(:system) }
  let(:activation) { FactoryGirl.build(:activation, system: system) }

  it 'triggers after_commit callback' do
    expect(system).to receive(:share_registration)
    expect(activation).to receive(:share_registration)
    activation.save!
  end

  it 'triggers registration sharing' do
    expect(system).to receive(:share_registration)
    expect(RegistrationSharing).to receive(:share).with(activation)
    activation.save!
  end
end
