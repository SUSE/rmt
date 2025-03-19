class BackfillUpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    System.unscoped.in_batches do |relation|
      relation.update_all proxy_byos_mode: 0
      sleep(0.01)
    end
  end
end
