class AddProxyByosToSystems < ActiveRecord::Migration[6.1]
  def up
    add_column :systems, :proxy_byos, :boolean
    change_column_default :systems, :proxy_byos, false

    # NOTE: no longer relevant as this has been moved into an enum instead of a
    # boolean value.
    System.update_all(proxy_byos: false)
  end

  def down
    remove_column :systems, :proxy_byos
  end
end
