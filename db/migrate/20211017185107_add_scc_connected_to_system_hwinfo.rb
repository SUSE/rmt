class AddSccConnectedToSystemHwinfo < ActiveRecord::Migration[6.1]
  def up
    add_column :hw_infos, :proxy_byos, :boolean
    change_column_default :hw_infos, :proxy_byos, false

    HwInfo.update_all(proxy_byos: false)
  end

  def down
    remove_column :hw_infos, :proxy_byos
  end
end
