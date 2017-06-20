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
      t.boolean :enabled, :default => false
      t.boolean :autorefresh, :default => true
      t.boolean :installer_updates, :null => false, :default => false
      t.string :external_url
      t.string :auth_token
    end

    create_table :systems do |t|
      t.string :login
      t.string :password
      t.string :guid
      t.string :secret
      t.string :hostname
      t.string :target
      t.integer :system_id
      t.datetime :registered_at
      t.datetime :last_seen_at
      t.timestamps
    end

    create_table :activations do |t|
      t.integer :service_id
      t.integer :system_id
      t.timestamps
    end

    create_table :services do |t|
      t.integer :product_id
      t.timestamps
    end

    create_table :repositories_services do |t|
      t.integer :repository_id
      t.integer :service_id
    end

    add_index :repositories, [:name, :distro_target], unique: true
    add_index :repositories_services, [:service_id, :repository_id], unique: true
    add_index :services, :product_id, unique: true

    add_foreign_key :repositories_services, :services, on_delete: :cascade
    add_foreign_key :repositories_services, :repositories, on_delete: :cascade

  end

end
