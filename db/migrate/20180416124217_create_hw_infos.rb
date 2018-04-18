class CreateHwInfos < ActiveRecord::Migration[5.1]
  def change
    create_table :hw_infos do |t|
      t.integer :cpus
      t.integer :sockets
      t.string :hypervisor, limit: 255, index: true
      t.string :arch, limit: 255
      t.integer :system_id
      t.string :uuid, limit: 255

      t.timestamps
    end

    add_index :hw_infos, :system_id, unique: true
    add_index :hw_infos, :uuid, unique: true
  end
end
