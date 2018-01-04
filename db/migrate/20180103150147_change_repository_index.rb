class ChangeRepositoryIndex < ActiveRecord::Migration[5.1]

  def up
    remove_index :repositories_services, column: %i[service_id repository_id]
    remove_foreign_key :repositories_services, :repositories
    remove_index :repositories_services, :repository_id

    change_column :repositories, :id, :string
    change_column :repositories_services, :repository_id, :string

    add_foreign_key :repositories_services, :repositories, column: :repository_id, on_delete: :cascade
    add_index :repositories_services, :repository_id
    add_index :repositories_services, %i[service_id repository_id], unique: true
  end

  def down
    remove_index :repositories_services, column: %i[service_id repository_id]
    remove_foreign_key :repositories_services, :repositories
    remove_index :repositories_services, :repository_id

    change_column :repositories, :id, :integer, limit: 8
    change_column :repositories_services, :repository_id, :integer, limit: 8

    add_foreign_key :repositories_services, :repositories, column: :repository_id, on_delete: :cascade
    add_index :repositories_services, :repository_id
    add_index :repositories_services, %i[service_id repository_id], unique: true
  end

end
