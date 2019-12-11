class AddCloudProviderToHwInfos < ActiveRecord::Migration[5.1]
  def change
    add_column :hw_infos, :cloud_provider, :string
  end
end
