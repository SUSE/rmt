class AddSystemTokenToSystems < ActiveRecord::Migration[6.1]
  def change
    add_column :systems, :system_token, :string
  end
end
