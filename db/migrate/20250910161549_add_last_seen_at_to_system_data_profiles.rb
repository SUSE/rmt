class AddLastSeenAtToSystemDataProfiles < ActiveRecord::Migration[6.1]
  def change
    add_column :system_data_profiles, :last_seen_at, :datetime, precision: 6, null: false
  end
end
