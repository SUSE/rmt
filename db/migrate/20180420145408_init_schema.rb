class InitSchema < ActiveRecord::Migration[5.1]
  def up
    create_table "activations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.bigint "service_id", null: false
      t.bigint "system_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["service_id"], name: "fk_rails_5ad14bc754"
      t.index ["system_id", "service_id"], name: "index_activations_on_system_id_and_service_id", unique: true
      t.index ["system_id"], name: "index_activations_on_system_id"
    end
    create_table "downloaded_files", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.string "checksum_type"
      t.string "checksum"
      t.string "local_path"
      t.bigint "file_size", unsigned: true
      t.index ["checksum_type", "checksum"], name: "index_downloaded_files_on_checksum_type_and_checksum", unique: true
    end
    create_table "hw_infos", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.integer "cpus"
      t.integer "sockets"
      t.string "hypervisor"
      t.string "arch"
      t.integer "system_id"
      t.string "uuid"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["hypervisor"], name: "index_hw_infos_on_hypervisor"
      t.index ["system_id"], name: "index_hw_infos_on_system_id", unique: true
    end
    create_table "product_predecessors", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.bigint "product_id", null: false
      t.bigint "predecessor_id"
      t.integer "kind", default: 0, null: false
      t.index ["predecessor_id"], name: "fk_rails_ae2fd616af"
      t.index ["product_id", "predecessor_id"], name: "index_product_predecessors_on_product_id_and_predecessor_id", unique: true
      t.index ["product_id"], name: "index_product_predecessors_on_product_id"
    end
    create_table "products", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.string "name"
      t.text "description"
      t.string "friendly_name"
      t.string "shortname"
      t.string "former_identifier"
      t.string "product_type"
      t.string "product_class"
      t.string "release_type"
      t.string "release_stage"
      t.string "identifier"
      t.string "version"
      t.string "arch"
      t.string "eula_url"
      t.boolean "free"
      t.string "cpe"
    end
    create_table "products_extensions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.bigint "product_id", null: false
      t.bigint "extension_id", null: false
      t.boolean "recommended"
      t.bigint "root_product_id", null: false
      t.index ["extension_id"], name: "index_products_extensions_on_extension_id"
      t.index ["product_id", "extension_id", "root_product_id"], name: "index_products_extensions_on_product_extension_root", unique: true
      t.index ["product_id"], name: "index_products_extensions_on_product_id"
      t.index ["root_product_id"], name: "fk_rails_7d0e68d364"
    end
    create_table "repositories", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.bigint "scc_id", unsigned: true
      t.string "name", null: false
      t.string "description"
      t.boolean "enabled", default: false, null: false
      t.boolean "autorefresh", default: true, null: false
      t.string "external_url", null: false
      t.string "auth_token"
      t.boolean "installer_updates", default: false, null: false
      t.boolean "mirroring_enabled", default: false, null: false
      t.string "local_path", null: false
      t.datetime "last_mirrored_at"
      t.index ["external_url"], name: "index_repositories_on_external_url", unique: true
    end
    create_table "repositories_services", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.bigint "repository_id", null: false
      t.bigint "service_id", null: false
      t.index ["repository_id"], name: "index_repositories_services_on_repository_id"
      t.index ["service_id", "repository_id"], name: "index_repositories_services_on_service_id_and_repository_id", unique: true
      t.index ["service_id"], name: "index_repositories_services_on_service_id"
    end
    create_table "services", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.bigint "product_id", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["product_id"], name: "index_services_on_product_id", unique: true
    end
    create_table "subscription_product_classes", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.bigint "subscription_id", null: false
      t.string "product_class", null: false
      t.index ["subscription_id", "product_class"], name: "index_product_class_unique", unique: true
      t.index ["subscription_id"], name: "index_subscription_product_classes_on_subscription_id"
    end
    create_table "subscriptions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.string "regcode", null: false
      t.string "name", null: false
      t.string "kind", null: false
      t.string "status", null: false
      t.datetime "starts_at"
      t.datetime "expires_at"
      t.integer "system_limit", null: false
      t.integer "systems_count", null: false
      t.integer "virtual_count"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["regcode"], name: "index_subscriptions_on_regcode"
    end
    create_table "systems", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
      t.string "login"
      t.string "password"
      t.string "guid"
      t.string "secret"
      t.string "hostname"
      t.string "target"
      t.datetime "registered_at"
      t.datetime "last_seen_at"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end
    add_foreign_key "activations", "services", on_delete: :cascade
    add_foreign_key "activations", "systems", on_delete: :cascade
    add_foreign_key "product_predecessors", "products", column: "predecessor_id"
    add_foreign_key "product_predecessors", "products", on_delete: :cascade
    add_foreign_key "products_extensions", "products", column: "extension_id", on_delete: :cascade
    add_foreign_key "products_extensions", "products", column: "root_product_id"
    add_foreign_key "products_extensions", "products", on_delete: :cascade
    add_foreign_key "repositories_services", "repositories", on_delete: :cascade
    add_foreign_key "repositories_services", "services", on_delete: :cascade
    add_foreign_key "services", "products"
    add_foreign_key "subscription_product_classes", "subscriptions", on_delete: :cascade
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "The initial migration is not revertable"
  end
end
