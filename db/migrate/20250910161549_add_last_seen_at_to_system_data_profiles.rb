class AddLastSeenAtToSystemDataProfiles < ActiveRecord::Migration[6.1]
  def change
    # TODO: resolve Rails/NotNullColumn issue, possibly by merging relevant migration scripts
    add_column :system_data_profiles, :last_seen_at, :datetime, precision: 6, null: false # rubocop:disable Rails/NotNullColumn
  end
end
