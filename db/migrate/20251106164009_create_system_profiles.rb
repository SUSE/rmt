class CreateSystemProfiles < ActiveRecord::Migration[6.1]
  def change
    create_table :system_profiles do |t|
      t.references :system, null: false, foreign_key: true
      t.references :profile, null: false, foreign_key: true

      t.timestamps
    end
  end
end
