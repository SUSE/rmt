class AddSccConnectedToSystemHwinfo < ActiveRecord::Migration[6.1]
  def up
    add_column :hw_infos, :scc_connected, :boolean
    change_column_default :hw_infos, :scc_connected, false

    HwInfo.update_all(scc_connected: false)
  end

  def down
    remove_column :hw_infos, :scc_connected
  end
end
