require 'rails_helper'

RSpec.describe SystemProfile, type: :model do
  it { is_expected.to belong_to(:system) }
  it { is_expected.to belong_to(:profile) }

  it { is_expected.to have_db_column(:system_id).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:profile_id).of_type(:integer).with_options(null: false) }

  describe 'cascaded destroy of profiles records' do
    context 'when destroying the last system_profile referencing a profile' do
      let!(:last_profile_link) { create(:system_profile) }

      it 'the associated profile is destroyed' do
        # system_profile destroy should remove last link to profile,
        # triggering cascaded destroy of profile
        expect { last_profile_link.destroy }.to change(Profile, :count).by(-1)
      end
    end

    context 'when destroying a system_profile reference to a profile with multiple references' do
      # create a profile that will be referenced by two system_profiles
      let!(:shared_profile) { create(:profile) }

      # create two system_profile entries referencing shared_profile
      let!(:system_profile_a) { create(:system_profile, profile: shared_profile) }
      let!(:system_profile_b) { create(:system_profile, profile: shared_profile) }

      it 'does not destroy the referenced profile' do
        expect { system_profile_a.destroy }.not_to change(Profile, :count)
      end

      it 'only destroys the specific system profile' do
        expect { system_profile_a.destroy }.to change(described_class, :count).by(-1)
      end

      it 'does not affect other references to shared profile' do
        system_profile_a.destroy
        expect(described_class.find(system_profile_b.id)).to eq(system_profile_b)
      end
    end
  end
end
