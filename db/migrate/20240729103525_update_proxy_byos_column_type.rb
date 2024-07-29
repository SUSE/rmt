class UpdateProxyByosColumnType < ActiveRecord::Migration[6.1]
  def change
    change_column(:systems, :proxy_byos, :integer, default: 0)
  end
end
