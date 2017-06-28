class CreateProductsAndRepositories < ActiveRecord::Migration[5.1]

  def change # rubocop:disable Metrics/MethodLength
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
      t.string :name, null: false
      t.string :distro_target
      t.string :description
      t.boolean :enabled, null: false, default: false
      t.boolean :autorefresh, null: false, default: true
      t.string :external_url, null: false
      t.string :auth_token
    end

    create_table :systems do |t|
      t.string :login
      t.string :password
      t.string :guid
      t.string :secret
      t.string :hostname
      t.string :target
      t.datetime :registered_at
      t.datetime :last_seen_at
      t.timestamps
    end

    create_table :activations do |t|
      t.integer :service_id, null: false
      t.integer :system_id, null: false
      t.timestamps
    end

    create_table :services do |t|
      t.integer :product_id, null: false
      t.timestamps
    end

    create_table :repositories_services do |t|
      t.integer :repository_id, null: false
      t.integer :service_id, null: false
    end

    create_table :products_extensions do |t|
      t.integer :product_id, null: false
      t.integer :extension_id, null: false
    end

    add_index :repositories, [:name, :distro_target], unique: true
    add_index :repositories_services, [:service_id, :repository_id], unique: true
    add_index :services, :product_id, unique: true

    add_foreign_key :activations, :systems, on_delete: :cascade

    add_foreign_key :repositories_services, :services, on_delete: :cascade
    add_foreign_key :repositories_services, :repositories, on_delete: :cascade

    add_foreign_key :products_extensions, :products, on_delete: :cascade
    add_foreign_key :products_extensions, :products, column: :extension_id, on_delete: :cascade

  end

end
