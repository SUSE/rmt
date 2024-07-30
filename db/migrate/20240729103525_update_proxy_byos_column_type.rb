class UpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :proxy_byos_mode, :integer, default: 0
    safety_assured do
      execute 'Update systems SET proxy_byos_mode = 0 WHERE proxy_byos = false'
      execute 'Update systems SET proxy_byos_mode = 1 WHERE proxy_byos = true'
    end
  end

  def down
    remove_column :systems, :proxy_byos_mode
  end
end
