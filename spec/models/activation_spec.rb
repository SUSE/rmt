require 'rails_helper'

RSpec.describe Activation, type: :model do
  it { is_expected.to belong_to :service }
  it { is_expected.to belong_to :system }
  it { is_expected.to have_one :product }

  it { is_expected.to validate_presence_of(:system) }
  it { is_expected.to validate_presence_of(:service) }

  it { is_expected.to have_db_column(:system_id).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:service_id).of_type(:integer).with_options(null: false) }

  subject { FactoryGirl.create :activation, system_id: system.id }

  let(:system) { FactoryGirl.create :system }
end
