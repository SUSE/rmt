class SubscriptionProductClass < ApplicationRecord

  validates :subscription_id, presence: true
  validates :product_class, presence: true
  validates :product_class, uniqueness: { scope: :subscription_id }, presence: true

  belongs_to :subscription

end
