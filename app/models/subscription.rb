class Subscription < ApplicationRecord

  enum kind: { test: 'test', full: 'full', evaluation: 'evaluation', oem: 'oem', provisional: 'provisional' }
  enum status: { expired: 'EXPIRED', active: 'ACTIVE', notactivated: 'NOTACTIVATED' }

  validates :regcode, presence: true
  validates :name, presence: true
  validates :kind, presence: true # column name 'type' is reserved by ActiveRecord
  validates :status, presence: true
  validates :system_limit, presence: true

  has_many :product_classes, foreign_key: 'subscription_id', class_name: 'SubscriptionProductClass'
  has_many :products, through: :product_classes

  def expired?
    !!(expires_at < Time.zone.now.beginning_of_day if expires_at)
  end

end
