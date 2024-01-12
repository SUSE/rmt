class CreateSystemUptimes < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      create_table :system_uptimes, id: :serial, force: :cascade do |t|
        t.bigint :system_id, null: false
        t.date :online_at_day, null: false
        t.column :online_at_hours, 'binary(24)', null: false
        t.timestamps
      end

      commit_db_transaction

      add_index :system_uptimes, %i[system_id online_at_day], unique: true, name: 'id_online_day'

      add_foreign_key :system_uptimes, :systems, column: :system_id, validate: false
    end
  end
end
