require 'spec_helper'
require 'rails_helper'

describe HwInfo do
  subject { create(:system, :with_hw_info).hw_info }

  let(:valid_uuid) { 'aaaaaaaa-aaaa-4aaa-9aaa-aaaaaaaaaaaa' }

  it { should belong_to :system }
  it { should validate_presence_of :system }

  it 'enforces uniqueness' do
    expect(subject).to validate_uniqueness_of(:system)
  end

  describe '.uuid' do
    it { should allow_value(nil).for(:uuid) }
    it { should allow_value('xyzzy').for(:uuid) }

    it 'forces invalid uuid to nil' do
      subject.uuid = 'xyzzy'
      subject.save!

      expect(subject.uuid).to be nil
    end

    it_should_behave_like 'model with UUID format validation and nil forcing', :uuid

    it 'has case-insensitive validations' do
      subject.uuid = valid_uuid.upcase
      subject.save!

      hw_info = build :hw_info, uuid: valid_uuid.downcase
      expect(hw_info).not_to be_valid
    end

    it 'is saved downcased in the DB' do
      subject.uuid = valid_uuid.upcase
      subject.save!

      hw_info = described_class.find_by(uuid: valid_uuid.downcase)
      expect(hw_info).to eq(subject)
    end
  end
end
