class AddRegsharingColumns < ActiveRecord::Migration[5.1]
  def change
    add_column :systems, :scc_system_id, :bigint, comment: 'System ID in SCC (if the system registration was forwarded; needed for forwarding de-registrations)'

    create_table :deregistered_systems do |t|
      t.bigint(
        :scc_system_id,
        null: false,
        index: { unique: true },
        comment: 'SCC IDs of deregistered systems; used for forwarding to SCC'
      )
      t.timestamps
    end
  end
end
