class AddLastMirroredAt < ActiveRecord::Migration[5.1]

  def change
    add_column :repositories, :last_mirrored_at, :datetime
  end

end
