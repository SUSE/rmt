class UpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      add_column :systems, :proxy_byos_mode, :integer, default: 0
      execute 'Update systems SET proxy_byos_mode = 0 WHERE proxy_byos = false'
      execute 'Update systems SET proxy_byos_mode = 1 WHERE proxy_byos = true'
      # remove_column :systems, :proxy_byos
    end
  end

  def down
    safety_assured do
      add_column :systems, :proxy_byos, :boolean, default: false
      execute 'Update systems SET proxy_byos = false WHERE proxy_byos_mode = 0'
      execute 'Update systems SET proxy_byos = true WHERE proxy_byos_mode = 1'
      # remove_column :systems, :proxy_byos_method
    end
  end
end
