class BackfillUpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    System.where(proxy_byos: false).where.not(instance_data: nil).in_batches do |relation|
      relation.update_all proxy_byos_mode: :payg
      sleep(0.01)
    end

    System.where(proxy_byos: true).in_batches do |relation|
      relation.update_all proxy_byos_mode: :byos
      sleep(0.01)
    end

    System.unscoped.where(proxy_byos_mode: nil).in_batches do |relation|
      relation.update_all proxy_byos_mode: 0
      sleep(0.01)
    end
  end
end
