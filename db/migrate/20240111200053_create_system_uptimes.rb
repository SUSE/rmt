class CreateSystemUptimes < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      create_table :system_uptimes do |t|
        t.bigint :system_id, null: false
        t.date :online_at_day, null: false
        t.column :online_at_hours, 'binary(24)', null: false
        t.timestamps
      end

      # NOTE: it was originally here but it doesn't make sense and it's
      # (rightfully) failing on SQLite3. Let's comment this one out.
      #
      # commit_db_transaction

      add_index :system_uptimes, %i[system_id online_at_day], unique: true, name: 'id_online_day'

      add_foreign_key :system_uptimes, :systems, column: :system_id, validate: false
    end
  end
end
