class UpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :proxy_byos_mode, :integer, default: 0
    System.where(proxy_byos: false).in_batches.update_all proxy_byos_mode: 0
    System.where(proxy_byos: true).in_batches.update_all proxy_byos_mode: 1
  end

  def down
    remove_column :systems, :proxy_byos_mode
  end
end
