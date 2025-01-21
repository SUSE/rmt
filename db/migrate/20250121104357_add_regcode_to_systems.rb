class AddRegcodeToSystems < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :reg_code, :string
    change_column_default :systems, :reg_code, nil
  end

  def down
    remove_column :systems, :reg_code
  end
end
