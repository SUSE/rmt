class MoveEnabledToRepoServices < ActiveRecord::Migration[5.1]

  def up
    add_column :repositories, :installer_updates, :boolean, null: false, default: false
    add_column :repositories, :mirroring_enabled, :boolean, null: false, default: false
    add_column :repositories, :local_path, :string
    Repository.all.each do |repo|
      repo.local_path = Repository.make_local_path(repo.external_url)
      repo.save!
    end
    change_column :repositories, :local_path, :string, null: false
    remove_index :repositories, name: 'index_repositories_on_name_and_distro_target'
    add_index :repositories, :external_url, unique: true
  end

  def down
    remove_column :repositories, :installer_updates
    remove_column :repositories, :mirroring_enabled
    remove_column :repositories, :local_path
    add_index :repositories, %i[name distro_target], unique: true
    remove_index :repositories, name: 'index_repositories_on_external_url'
  end

end
