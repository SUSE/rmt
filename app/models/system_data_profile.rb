class SystemDataProfile < ApplicationRecord
  # relationships
  has_many :system_profiles
  has_many :systems, through: :system_profiles

  validates :profile_type, presence: true
  validates :profile_id, presence: true
  validates :profile_data, presence: true, on: create
  validates :last_seen_at, presence: true

  def self.Where_Unique_Keys(key_tuples)
    # generate an expanded where clause with one entry per key_tuple
    # and pass the flattened list of key tuples as arguments
    self.where(
      key_tuples.map { "(profile_type = ? AND profile_id = ?)" }.join(" OR "),
      *(key_tuples.flatten),
    )
  end
end