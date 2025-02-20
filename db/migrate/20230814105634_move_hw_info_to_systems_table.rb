class MoveHwInfoToSystemsTable < ActiveRecord::Migration[6.1]
  def sqlite?
    ActiveRecord::Base.connection.adapter_name == 'SQLite'
  end

  def up
    safety_assured do
      change_column :systems, :instance_data, :text

      unless sqlite?
      execute "UPDATE systems AS s INNER JOIN hw_infos hw ON s.id=hw.system_id \
                SET s.system_information = json_object(                        \
                'cpus', hw.cpus,                                               \
                'sockets', hw.sockets,                                         \
                'hypervisor', nullif(hw.hypervisor, ''),                       \
                'arch', nullif(hw.arch, ''),                                   \
                'uuid', nullif(hw.uuid, ''),                                   \
                'cloud_provider', nullif(hw.cloud_provider, '')),              \
                s.instance_data = hw.instance_data;"
      end
    end
  end

  def down
    change_column :systems, :instance_data, :string
  end
end
