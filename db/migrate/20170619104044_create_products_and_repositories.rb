class CreateProductsAndRepositories < ActiveRecord::Migration[5.1]

  def change
    create_table :products do |t|
      t.string :name
      t.string :description
      t.string :friendly_name
      t.string :shortname
      t.string :former_identifier
      t.string :product_type
      t.string :product_class
      t.string :release_type
      t.string :release_stage
      t.string :identifier
      t.string :version
      t.string :arch
      t.string :eula_url
      t.boolean :free
      t.boolean :available
      t.string :cpe
    end

    create_table :repositories do |t|
      t.string :name
      t.string :distro_target
      t.string :description
      t.boolean :enabled
      t.boolean :autorefresh
      t.boolean :installer_updates
      t.string :external_url
    end

    create_table :products_repositories do |t|
      t.integer :product_id
      t.integer :repository_id
    end

    add_index :repositories, [:name, :distro_target], unique: true
    add_index :products_repositories, [:product_id, :repository_id], unique: true

    add_foreign_key :products_repositories, :products, on_delete: :cascade
    add_foreign_key :products_repositories, :repositories, on_delete: :cascade
  end

end
