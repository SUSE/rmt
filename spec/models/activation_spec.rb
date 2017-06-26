require 'rails_helper'

RSpec.describe Activation, type: :model do
  it { should belong_to :service }
  it { should belong_to :system }
  it { should have_one :product }

  it { should validate_presence_of(:system).with_message(/must exist/) }
  it { should validate_presence_of(:service).with_message(/must exist/) }

  let(:system) { FactoryGirl.create :system }
  subject { FactoryGirl.create :activation, system_id: system.id }
end
