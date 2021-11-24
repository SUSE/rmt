require 'rails_helper'

RSpec.describe Subscription, type: :model do
  it { is_expected.to validate_presence_of(:regcode) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:kind) }
  it { is_expected.to validate_presence_of(:status) }
  it { is_expected.to validate_presence_of(:system_limit) }

  it { is_expected.to have_many :product_classes }

  describe '#expired?' do
    let(:expired) { create(:subscription, status: 'EXPIRED', expires_at: 1.month.ago) }
    let(:active) { create(:subscription, status: 'ACTIVE') }

    it 'returns true for expired subscriptions' do
      expect(expired.expired?).to be_truthy
    end

    it 'returns false for active subscriptions' do
      expect(active.expired?).to be_falsey
    end
  end
end
