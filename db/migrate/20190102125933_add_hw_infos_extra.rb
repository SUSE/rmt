class AddHwInfosExtra < ActiveRecord::Migration[5.1]
  def change
      add_column :hw_infos, :extra_data, :text, comment: 'Additional client information, e.g. instance identity document'
  end
end
