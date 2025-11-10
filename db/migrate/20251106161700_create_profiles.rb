class CreateProfiles < ActiveRecord::Migration[6.1]
  def change
    create_table :profiles do |t|
      t.string :profile_type, null: false
      t.string :identifier, null: false
      t.text :data, null: false
      t.timestamp :last_synced_at

      t.timestamps
    end

    add_index :profiles, %i[profile_type identifier], unique: true
  end
end
