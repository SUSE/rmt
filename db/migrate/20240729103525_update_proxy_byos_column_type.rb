class UpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :proxy_byos_mode, :integer, default: nil
    System.where(proxy_byos: true).in_batches.update_all proxy_byos_mode: 1
  end

  def down
    System.where(proxy_byos_mode: :byos).in_batches.update_all proxy_byos: true
    remove_column :systems, :proxy_byos_mode
  end
end
