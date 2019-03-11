require 'rails_helper'

describe System, type: :model do
  let(:system) { FactoryGirl.build(:system) }

  it 'triggers after_commit callback' do
    expect(system).to receive(:share_registration)
    system.save!
  end

  it 'triggers registration sharing' do
    expect(RegistrationSharing).to receive(:called_from_regsharing?).and_return(false)
    expect(RegistrationSharing).to receive(:save_for_sharing).with(system)
    system.save!
  end
end
