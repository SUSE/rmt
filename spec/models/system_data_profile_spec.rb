require 'rails_helper'

RSpec.describe SystemDataProfile, type: :model do
  it { is_expected.to validate_presence_of(:profile_type) }
  it { is_expected.to validate_presence_of(:profile_id) }
  it { is_expected.to validate_presence_of(:profile_data) }
  it { is_expected.to validate_presence_of(:last_seen_at) }
end
