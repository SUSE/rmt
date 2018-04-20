class RemoveHwInfoUuidIndex < ActiveRecord::Migration[5.1]
  def change
    remove_index :hw_infos, :uuid
  end
end
