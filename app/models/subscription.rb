class Subscription < ApplicationRecord

  # we avoid to name enum key 'test' because it will override existing private method
  enum kind: { is_test: 'test', full: 'full', evaluation: 'evaluation', oem: 'oem', provisional: 'provisional', internal: 'internal' }
  enum status: { expired: 'EXPIRED', active: 'ACTIVE', notactivated: 'NOTACTIVATED' }

  validates :regcode, presence: true
  validates :name, presence: true
  validates :kind, presence: true # column name 'type' is reserved by ActiveRecord
  validates :status, presence: true
  validates :system_limit, presence: true

  has_many :product_classes, foreign_key: 'subscription_id', class_name: 'SubscriptionProductClass'
  has_many :products, through: :product_classes

end
