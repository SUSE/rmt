class AddLastExportedAtToSystemDataProfiles < ActiveRecord::Migration[6.1]
  def change
    add_column :system_data_profiles, :last_exported_at, :datetime
  end
end
