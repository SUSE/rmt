class AddIndexToSystemsSystemToken < ActiveRecord::Migration[6.1]
  def change
    add_index :systems, %i[system_token]
  end
end
