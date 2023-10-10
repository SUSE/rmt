class MoveHwInfoToSystemsTable < ActiveRecord::Migration[6.1]
  def up
    safety_assured do
      execute "update systems as s inner join hw_infos hw on s.id=hw.system_id \
                set system_information = json_object(\
                'cpus', hw.cpus, \
                'sockets', hw.sockets, \
                'hypervisor', nullif(hw.hypervisor, ''), \
                'arch', nullif(hw.arch, ''), \
                'uuid', nullif(hw.uuid, ''), \
                'cloud_provider', nullif(hw.cloud_provider, ''));"
    end
  end

  def down
    safety_assured do
      execute 'update systems set system_information = json_object();'
    end
  end
end