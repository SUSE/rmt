class DropUnusedSystemColumns < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      remove_column :systems, :target, :string
      remove_column :systems, :guid, :string
      remove_column :systems, :secret, :string
    end
  end
end
