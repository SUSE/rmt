class SystemUptime < ApplicationRecord
  belongs_to :system

  validates :system_id, presence: true
  validates :online_at_day, presence: true
  validates :online_at_hours, presence: true
end
