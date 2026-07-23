class RemoveProxyByosFromSystems < ActiveRecord::Migration[8.1]
  def change
    if column_exists?(:systems, :proxy_byos)
      remove_column :systems, :proxy_byos, :boolean, default: false
    end
  end
end
