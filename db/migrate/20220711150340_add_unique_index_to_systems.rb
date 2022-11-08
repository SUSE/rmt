class AddUniqueIndexToSystems < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :systems, %i[login password system_token], unique: true
  end
end
