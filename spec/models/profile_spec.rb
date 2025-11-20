require 'rails_helper'

RSpec.describe Profile, type: :model do
  include_context 'profile sets'

  it { is_expected.to validate_presence_of(:profile_type) }
  it { is_expected.to validate_presence_of(:identifier) }
  it { is_expected.to validate_presence_of(:data) }

  it { is_expected.to have_db_column(:profile_type).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:identifier).of_type(:string).with_options(null: false) }
  it { is_expected.to have_db_column(:data).of_type(:text).with_options(null: false) }

  context 'filter_profiles' do
    let(:profiles) { profile_set_mixed }

    it 'filters profiles appropriately' do
      complete, incomplete, invalid = described_class.filter_profiles(profiles)

      expect(complete).to eq(profile_set_mixed_complete)
      expect(incomplete).to eq(profile_set_mixed_incomplete)
      expect(invalid).to eq(profile_set_mixed_invalid)
    end

    it 'considers profiles with empty identifiers as invalid' do
      complete, incomplete, invalid = described_class.filter_profiles(profile_set_empty)

      expect(complete).to eq({})
      expect(incomplete).to eq({})
      expect(invalid).to eq(profile_set_empty)
    end
  end

  context 'identify_existing_profiles' do
    let(:expected) { profile_set_b }
    let(:ptype) { expected.keys.first }
    let(:pinfo) { expected[ptype] }
    let(:missing_profiles) { profile_set_a1_no_data }
    let(:profiles) { expected.merge(missing_profiles) }

    before do
      create(:profile, profile_type: ptype, identifier: pinfo[:identifier], data: pinfo[:data])
    end

    it 'finds existing profile' do
      expect(described_class.identify_known_profiles(profiles)).to match(expected)
    end

    it 'does not find missing profiles' do
      expect(described_class.identify_known_profiles(missing_profiles)).to match({})
    end

    it 'handles empty profile search list' do
      expect(described_class.identify_known_profiles({})).to match({})
    end
  end

  context 'ensure_profile_exists creates profile' do
    let(:expected) { profile_set_b }
    let(:ptype) { expected.keys.first }
    let(:pinfo) { expected[ptype] }

    it 'if not found' do
      profile = described_class.ensure_profile_exists(ptype, pinfo)

      expect(described_class.count).to eq(1)
      expect(profile).to be_an_instance_of(described_class)
      expect(
        {
          profile.profile_type => {
            identifier: profile.identifier,
            data: profile.data
          }
        }.symbolize_keys
      ).to match(expected)
    end
  end

  context 'ensure_profile_exists existing profile handling' do
    let(:expected) { profile_set_b }
    let(:ptype) { expected.keys.first }
    let(:pinfo) { expected[ptype] }
    let!(:existing_profile) { create(:profile, profile_type: ptype, identifier: pinfo[:identifier], data: pinfo[:data]) }

    it 'use existing profile if found' do
      profile = described_class.ensure_profile_exists(ptype, pinfo)

      expect(described_class.count).to eq(1)
      expect(profile).to be_an_instance_of(described_class)
      expect(profile).to eq(existing_profile)
      expect(
        {
          profile.profile_type => {
            identifier: profile.identifier,
            data: profile.data
          }
        }.symbolize_keys
      ).to match(expected)
    end
  end

  context 'ensure_profile_exists rescue handling' do
    let(:expected) { profile_set_b }
    let(:ptype) { expected.keys.first }
    let(:pinfo) { expected[ptype] }
    let(:where_params) { { profile_type: ptype, identifier: pinfo[:identifier] } }
    let!(:existing_profile) { create(:profile, profile_type: ptype, identifier: pinfo[:identifier], data: pinfo[:data]) }

    it 'create collision rescue handling returns newly created profile' do
      # Create a mock relation to use in the mocking of the ensure_profile_exists()
      profile_relation = instance_double('ActiveRecord::Relation')

      # Next mock the where() call to return the above mock relation
      allow(described_class).to receive(:where).with(where_params).and_return(profile_relation)

      # Then mock the first_or_create!()i call on that mock relation
      # so that it raises ActiveRecord::RecordNotUnique to trigger the
      # rescue block.
      allow(profile_relation).to receive(:first_or_create!).and_raise(ActiveRecord::RecordNotUnique)

      # Finally mock the lock() and first!() calls on the mocked
      # relation that is returned by the where() call above so
      # that the rescue actions can be completed.
      allow(profile_relation).to receive(:lock).and_return(profile_relation)
      allow(profile_relation).to receive(:first!).and_return(existing_profile)

      expect { described_class.ensure_profile_exists(ptype, pinfo) }.not_to raise_error

      profile = described_class.ensure_profile_exists(ptype, pinfo)

      expect(described_class.count).to eq(1)
      expect(profile).to be_an_instance_of(described_class)
      expect(profile).to eq(existing_profile)
      expect(
        {
          profile.profile_type => {
            identifier: profile.identifier,
            data: profile.data
          }
        }.symbolize_keys
      ).to match(expected)
    end
  end
end
