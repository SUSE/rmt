class AddIndexToSystemsHostname < ActiveRecord::Migration[8.1]
  def change
    add_index :systems, :hostname, unique: false
  end
end
