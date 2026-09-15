class RemoveProxyByosFromSystems < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      if column_exists?(:systems, :proxy_byos)
        remove_column :systems, :proxy_byos, :boolean, default: false
      end
    end
  end
end
