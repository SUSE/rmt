class CreateSubscriptions < ActiveRecord::Migration[5.1]

  def change
    create_table :subscriptions do |t|
      t.string :regcode, null: false
      t.string :name, null: false
      t.string :kind, null: false
      t.string :status, null: false

      t.datetime :starts_at
      t.datetime :expires_at

      t.integer :system_limit, null: false
      t.integer :systems_count, null: false
      t.integer :virtual_count

      t.timestamps
    end

    add_index :subscriptions, :regcode
  end

end
