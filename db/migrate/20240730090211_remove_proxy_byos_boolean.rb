class RemoveProxyByosBoolean < ActiveRecord::Migration[6.1]
  def up
    safety_assured { remove_column :systems, :proxy_byos }
  end

  def down
    add_column :systems, :proxy_byos, :boolean, default: false
    System.where(proxy_byos_mode: 0).in_batches.update_all proxy_byos: false
    System.where(proxy_byos_mode: 1).in_batches.update_all proxy_byos: true
  end
end
