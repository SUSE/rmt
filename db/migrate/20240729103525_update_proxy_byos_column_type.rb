class UpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :proxy_byos_boolean, :boolean, default: false
    safety_assured do
      execute 'Update systems SET proxy_byos_boolean = false WHERE proxy_byos = false'
      execute 'Update systems SET proxy_byos_boolean = true WHERE proxy_byos = true'
      remove_column :systems, :proxy_byos
      add_column :systems, :proxy_byos, :integer, default: 0
      execute 'Update systems SET proxy_byos = 0 WHERE proxy_byos_boolean = false'
      execute 'Update systems SET proxy_byos = 1 WHERE proxy_byos_boolean = true'
      remove_column :systems, :proxy_byos_boolean
    end
  end

  def down
    add_column :systems, :proxy_byos_boolean, :boolean, default: false
    safety_assured do
      execute 'Update systems SET proxy_byos_boolean = false WHERE proxy_byos = 0'
      execute 'Update systems SET proxy_byos_boolean = true WHERE proxy_byos = 1'
      remove_column :systems, :proxy_byos
      add_column :systems, :proxy_byos, :boolean, default: false
      execute 'Update systems SET proxy_byos = false WHERE proxy_byos_boolean = false'
      execute 'Update systems SET proxy_byos = true WHERE proxy_byos_boolean = true'
      remove_column :systems, :proxy_byos_boolean
    end
  end
end
