require 'rails_helper'

RSpec.describe Subscription, type: :model do
  it { is_expected.to validate_presence_of(:regcode) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:kind) }
  it { is_expected.to validate_presence_of(:status) }
  it { is_expected.to validate_presence_of(:system_limit) }

  it { is_expected.to have_many :product_classes }
end
