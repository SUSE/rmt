require 'spec_helper'
require 'rails_helper'

describe HwInfo do
  subject(:hw_info) { create(:system, :with_hw_info).hw_info }

  let(:valid_uuid) { 'aaaaaaaa-aaaa-4aaa-9aaa-aaaaaaaaaaaa' }

  it { is_expected.to belong_to :system }
  it { is_expected.to validate_presence_of :system }

  it 'enforces uniqueness' do
    expect(hw_info).to validate_uniqueness_of(:system)
  end

  describe '.uuid' do
    it { is_expected.to allow_value(nil).for(:uuid) }
    it { is_expected.to allow_value('xyzzy').for(:uuid) }

    it 'forces invalid uuid to nil' do
      hw_info.uuid = 'xyzzy'
      hw_info.save!

      expect(hw_info.uuid).to be nil
    end

    it 'keeps valid uuid' do
      hw_info.uuid = valid_uuid
      hw_info.save!

      expect(hw_info.uuid).to eq(valid_uuid)
    end

    it 'does not allow to had downcased UUID' do
      hw_info.uuid = valid_uuid.upcase
      hw_info.save!

      new_hw_info = build :hw_info, uuid: valid_uuid.downcase
      expect(new_hw_info).not_to be_valid
    end

    it 'is saved downcased in the DB' do
      hw_info.uuid = valid_uuid.upcase
      hw_info.save!

      copy_hw_info = described_class.find_by(uuid: valid_uuid.downcase)
      expect(copy_hw_info).to eq(hw_info)
    end
  end
end
