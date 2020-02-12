class Activation < ApplicationRecord

  belongs_to :system
  belongs_to :service
  has_one :product, through: :service

  validates :system, presence: true
  validates :service, presence: true

  # reset SCC sync timestamp so that the system can be re-synced on change
  after_create do |activation|
    activation.system.scc_registered_at = nil
    activation.system.save!
  end
  after_update do |activation|
    activation.system.scc_registered_at = nil
    activation.system.save!
  end
  after_destroy do |activation|
    activation.system.scc_registered_at = nil
    activation.system.save!
  end
end
