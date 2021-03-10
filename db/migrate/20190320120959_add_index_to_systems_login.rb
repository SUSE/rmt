class AddIndexToSystemsLogin < ActiveRecord::Migration[5.1]
  def change
    add_index :systems, :login, unique: true
  end
end
