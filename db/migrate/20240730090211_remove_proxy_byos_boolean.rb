class RemoveProxyByosBoolean < ActiveRecord::Migration[6.1]
  def down
    System.where(proxy_byos_mode: :byos).in_batches.update_all proxy_byos: true
  end
end
