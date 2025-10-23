require 'rails_helper'

RSpec.describe SystemProfile, type: :model do
  it { is_expected.to belong_to(:system) }
  it { is_expected.to belong_to(:system_data_profile) }

  it { is_expected.to have_db_column(:system_id).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:system_data_profile_id).of_type(:integer).with_options(null: false) }

  describe 'cascaded deletion of SystemDataProfile' do
    context 'when destroying the last profile link to a data profile' do
      let!(:last_profile_link) { create(:system_profile) }

      it 'the associated data profile is destroyed' do
        expect(described_class.count).to eq(1)
        expect(SystemDataProfile.count).to eq(1)

        expect { last_profile_link.destroy }.to change(SystemDataProfile, :count).by(-1)
        expect(described_class.count).to eq(0)
      end
    end

    context 'when destroying a system profile link to a shared data profile' do
      # create a data profile to be shared by two systems
      let!(:shared_data_profile) { create(:system_data_profile) }

      # create two system profiles linked to the shared data profile
      let!(:system_profile_a) { create(:system_profile, system_data_profile: shared_data_profile) }
      let!(:system_profile_b) { create(:system_profile, system_data_profile: shared_data_profile) }

      it 'does not destroy the associated shared data profile' do
        expect { system_profile_a.destroy }.not_to change(SystemDataProfile, :count)
      end

      it 'only destroys the system profile link to the shared data profile' do
        expect { system_profile_a.destroy }.to change(described_class, :count).by(-1)
      end
    end
  end
end
