class SystemDataProfile < ApplicationRecord
  # relationships
  has_many :system_profiles
  has_many :systems, through: :system_profiles

  validates :profile_type, presence: true
  validates :profile_id, presence: true
  validates :profile_data, presence: true, on: create
  validates :last_seen_at, presence: true
end