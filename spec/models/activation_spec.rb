require 'rails_helper'

RSpec.describe Activation, type: :model do
  it { should belong_to :service }
  it { should belong_to :system }
  it { should have_one :product }

  it { should validate_presence_of(:system) }
  it { should validate_presence_of(:service) }

  it { should have_db_column(:system_id).of_type(:integer).with_options(null: false) }
  it { should have_db_column(:service_id).of_type(:integer).with_options(null: false) }

  let(:system) { FactoryGirl.create :system }
  subject { FactoryGirl.create :activation, system_id: system.id }
end
