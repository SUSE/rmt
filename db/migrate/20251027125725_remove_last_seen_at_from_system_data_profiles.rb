class RemoveLastSeenAtFromSystemDataProfiles < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      remove_column :system_data_profiles, :last_seen_at, :datetime
    end
  end
end
