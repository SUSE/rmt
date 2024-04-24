require 'rails_helper'

RSpec.describe SystemUptime, type: :model do
  it { is_expected.to validate_presence_of(:system_id) }
  it { is_expected.to validate_presence_of(:online_at_day) }
  it { is_expected.to validate_presence_of(:online_at_hours) }
end
