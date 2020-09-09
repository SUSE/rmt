class SubscriptionProductClass < ApplicationRecord

  validates :subscription_id, presence: true
  validates :product_class, presence: true
  validates :product_class, uniqueness: { case_sensitive: false, scope: :subscription_id }, presence: true

  belongs_to :subscription
  has_many :products, primary_key: 'product_class', foreign_key: 'product_class', class_name: 'Product'

end
