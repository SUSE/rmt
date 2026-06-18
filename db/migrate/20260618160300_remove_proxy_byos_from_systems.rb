class RemoveProxyByosFromSystems < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :systems, :proxy_byos, :boolean, default: false }
  end
end
