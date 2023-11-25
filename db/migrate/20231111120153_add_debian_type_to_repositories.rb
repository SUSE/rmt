class AddDebianTypeToRepositories < ActiveRecord::Migration[6.1]
  def change
    add_column :repositories, :repository_type, :string
    change_column_default :repositories, :repository_type, "repomd"

    Repository.update_all(repository_type: 'repomd')
  end

  def down
    Repository.remove_all(repository_type: 'debian')

    remove_column :repositories, :repository_type
  end
end
