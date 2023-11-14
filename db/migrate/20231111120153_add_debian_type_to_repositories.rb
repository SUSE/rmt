class AddDebianTypeToRepositories < ActiveRecord::Migration[6.1]
  def change
    add_column :repositories, :repository_type, :string

    Repository.update_all(repository_type: 'repomd')
  end

  def down
    Repository.remove_all(repository_type: 'debian')

    remove_column :repositories, :repository_type
  end
end
