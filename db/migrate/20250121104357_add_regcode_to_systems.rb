class AddRegcodeToSystems < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :pubcloud_reg_code, :string
    change_column_default :systems, :pubcloud_reg_code, nil
  end

  def down
    remove_column :systems, :pubcloud_reg_code
  end
end
