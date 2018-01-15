class AddSccIdToRepositories < ActiveRecord::Migration[5.1]

  def change
    add_column :repositories, :scc_id, 'BIGINT UNSIGNED', after: :id
    Repository.all.each do |repo|
      repo.update(scc_id: repo.id)
    end
  end

end
