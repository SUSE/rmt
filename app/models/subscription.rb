class Subscription < ApplicationRecord

  # we avoid to name enum key 'test' because it will override existing private method
  # The different subscription types are documented in:
  # https://github.com/SUSE/scc-docs/blob/master/projects/scc/architecture/business-logic/subscription-types.md
  # we avoid to name enum key 'test' because it will override existing private method
  enum :kind, {
    is_test: 'test', full: 'full', evaluation: 'evaluation', oem: 'oem', internal: 'internal', partner: 'partner'
  }

  enum :status, { expired: 'EXPIRED', active: 'ACTIVE', notactivated: 'NOTACTIVATED' }

  validates :regcode, presence: true
  validates :name, presence: true
  validates :kind, presence: true # column name 'type' is reserved by ActiveRecord
  validates :status, presence: true
  validates :system_limit, presence: true

  has_many :product_classes, class_name: 'SubscriptionProductClass'
  has_many :products, through: :product_classes

  def expired?
    expires_at? && expires_at < Time.zone.now.beginning_of_day
  end

  # query counterpart of #expired?. Deliberately not the negation of the
  # `expired` scope the status enum generates: that one matches
  # status = 'EXPIRED', which only changes when `rmt-cli sync` runs, whereas
  # expires_at is evaluated against the current time on every request.
  scope :not_expired, -> { where('expires_at IS NULL OR expires_at >= ?', Time.zone.now.beginning_of_day) }
end
