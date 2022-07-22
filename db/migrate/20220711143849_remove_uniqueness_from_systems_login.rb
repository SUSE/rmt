class RemoveUniquenessFromSystemsLogin < ActiveRecord::Migration[6.1]
  def change
    remove_index :systems, :login, name: 'index_systems_on_login'
  end
end
