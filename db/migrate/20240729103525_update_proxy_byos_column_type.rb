class UpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :proxy_byos_mode, :integer, default: 0
    System.where(proxy_byos: false).where.not(instance_data: nil).in_batches.update_all proxy_byos_mode: :payg
    System.where(proxy_byos: true).in_batches.update_all proxy_byos_mode: :byos
  end

  def down
    remove_column :systems, :proxy_byos_mode
  end
end
