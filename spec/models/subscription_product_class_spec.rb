require 'rails_helper'

RSpec.describe SubscriptionProductClass, type: :model do
  it { is_expected.to belong_to(:subscription) }

  it { is_expected.to validate_presence_of(:subscription_id) }
  it { is_expected.to validate_presence_of(:product_class) }

  it { is_expected.to have_db_column(:subscription_id).of_type(:integer).with_options(null: false) }
  it { is_expected.to have_db_column(:product_class).of_type(:string).with_options(null: false) }
end
