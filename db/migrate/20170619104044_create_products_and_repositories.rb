class CreateProductsAndRepositories < ActiveRecord::Migration[5.1]

  # rubocop:disable Metrics/MethodLength
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
      t.references :system, foreign_key: { on_delete: :cascade }, null: false
      t.timestamps
    end

    create_table :services do |t|
      t.integer :product_id, null: false
      t.timestamps
    end

    create_table :repositories_services do |t|
      t.references :repository, foreign_key: { on_delete: :cascade }, null: false
      t.references :service, foreign_key: { on_delete: :cascade }, null: false
    end

    create_table :products_extensions do |t|
      t.references :product, foreign_key: { on_delete: :cascade }, null: false
      t.references :extension, foreign_key: { to_table: :products, on_delete: :cascade }, null: false
    end

    add_index :repositories, %i[name distro_target], unique: true
    add_index :repositories_services, %i[service_id repository_id], unique: true
    add_index :services, :product_id, unique: true
  end

end
