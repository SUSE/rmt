class CreateSystemDataProfiles < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      create_table :system_data_profiles do |t|
        t.string :profile_type, limit: 32, null: false
        t.string :profile_id, limit: 64, null: false
        t.text :profile_data, null: false
        t.timestamps
      end

      commit_db_transaction

      add_index :system_data_profiles, %i[profile_type profile_id], unique: true
    end
  end
end
