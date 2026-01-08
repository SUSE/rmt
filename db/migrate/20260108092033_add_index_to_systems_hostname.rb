class AddIndexToSystemsHostname < ActiveRecord::Migration[5.1]
  def change
    add_index :systems, :hostname, unique: false
  end
end
