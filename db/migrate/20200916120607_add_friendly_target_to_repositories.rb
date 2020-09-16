class AddFriendlyTargetToRepositories < ActiveRecord::Migration[6.0]
  def change
    add_column :repositories, :friendly_id, :string
    add_index :repositories, :friendly_id, unique: true

    Repository.all.each do |repo|
      if repo.custom?
        repo.update(friendly_id: Repository.make_friendly_url_id(repo.external_url))
      else
        repo.update(friendly_id: repo.scc_id)
      end
    end
  end
end
