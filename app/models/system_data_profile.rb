class SystemDataProfile < ApplicationRecord
  validates :profile_type, presence: true
  validates :profile_id, presence: true
  validates :profile_data, presence: true
end