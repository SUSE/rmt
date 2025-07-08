class AddProxyByosModeToSystems < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :proxy_byos_mode, :integer, if_exists: false
    change_column_default :systems, :proxy_byos_mode, 0
  end

  def down
    remove_column :systems, :proxy_byos_mode, if_exists: true
  end
end
