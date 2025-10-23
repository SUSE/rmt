class UpdateLastSeenAtOnSystemDataProfiles < ActiveRecord::Migration[6.1]
  def change
    # Change the default value for last_seen_at from null to current time.
    change_column_default(
      :system_data_profiles,
      :last_seen_at,
      from: nil,
      to: -> { 'CURRENT_TIMESTAMP' }
    )
  end
end
