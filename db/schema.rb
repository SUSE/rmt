# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_13_142033) do
  create_table "activations", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "service_id", null: false
    t.bigint "subscription_id"
    t.bigint "system_id", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "fk_rails_5ad14bc754"
    t.index ["subscription_id"], name: "fk_rails_296466bd8d"
    t.index ["system_id", "service_id"], name: "index_activations_on_system_id_and_service_id", unique: true
    t.index ["system_id"], name: "index_activations_on_system_id"
  end

  create_table "deregistered_systems", charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "scc_system_id", null: false, comment: "SCC IDs of deregistered systems; used for forwarding to SCC"
    t.datetime "updated_at", null: false
    t.index ["scc_system_id"], name: "index_deregistered_systems_on_scc_system_id", unique: true
  end

  create_table "downloaded_files", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "checksum"
    t.string "checksum_type"
    t.bigint "file_size", unsigned: true
    t.string "local_path", limit: 512
    t.index ["checksum_type", "checksum"], name: "index_downloaded_files_on_checksum_type_and_checksum"
    t.index ["local_path"], name: "index_downloaded_files_on_local_path", unique: true
  end

  create_table "hw_infos", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "arch"
    t.string "cloud_provider"
    t.integer "cpus"
    t.datetime "created_at", null: false
    t.string "hypervisor"
    t.text "instance_data", comment: "Additional client information, e.g. instance identity document"
    t.integer "sockets"
    t.integer "system_id"
    t.datetime "updated_at", null: false
    t.string "uuid"
    t.index ["hypervisor"], name: "index_hw_infos_on_hypervisor"
    t.index ["system_id"], name: "index_hw_infos_on_system_id", unique: true
  end

  create_table "product_predecessors", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.integer "kind", default: 0, null: false
    t.bigint "predecessor_id"
    t.bigint "product_id", null: false
    t.index ["predecessor_id"], name: "fk_rails_ae2fd616af"
    t.index ["product_id", "predecessor_id"], name: "index_product_predecessors_on_product_id_and_predecessor_id", unique: true
    t.index ["product_id"], name: "index_product_predecessors_on_product_id"
  end

  create_table "products", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "arch"
    t.string "cpe"
    t.text "description"
    t.string "eula_url"
    t.string "former_identifier"
    t.boolean "free"
    t.string "friendly_version"
    t.string "identifier"
    t.string "name"
    t.string "product_class"
    t.string "product_type"
    t.string "release_stage"
    t.string "release_type"
    t.string "shortname"
    t.string "version"
  end

  create_table "products_extensions", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.bigint "extension_id", null: false
    t.boolean "migration_extra", default: false
    t.bigint "product_id", null: false
    t.boolean "recommended"
    t.bigint "root_product_id", null: false
    t.index ["extension_id"], name: "index_products_extensions_on_extension_id"
    t.index ["product_id", "extension_id", "root_product_id"], name: "index_products_extensions_on_product_extension_root", unique: true
    t.index ["product_id"], name: "index_products_extensions_on_product_id"
    t.index ["root_product_id"], name: "fk_rails_7d0e68d364"
  end

  create_table "repositories", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "auth_token"
    t.boolean "autorefresh", default: true, null: false
    t.string "description"
    t.boolean "enabled", default: false, null: false
    t.string "external_url", null: false
    t.string "friendly_id"
    t.boolean "installer_updates", default: false, null: false
    t.datetime "last_mirrored_at"
    t.string "local_path", limit: 512, null: false
    t.boolean "mirroring_enabled", default: false, null: false
    t.string "name", null: false
    t.bigint "scc_id", unsigned: true
    t.index ["external_url"], name: "index_repositories_on_external_url", unique: true
    t.index ["friendly_id"], name: "index_repositories_on_friendly_id", unique: true
    t.index ["scc_id"], name: "index_repositories_on_scc_id", unique: true
  end

  create_table "repositories_services", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.bigint "service_id", null: false
    t.index ["repository_id"], name: "index_repositories_services_on_repository_id"
    t.index ["service_id", "repository_id"], name: "index_repositories_services_on_service_id_and_repository_id", unique: true
    t.index ["service_id"], name: "index_repositories_services_on_service_id"
  end

  create_table "services", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_services_on_product_id", unique: true
  end

  create_table "subscription_product_classes", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.string "product_class", null: false
    t.bigint "subscription_id", null: false
    t.index ["subscription_id", "product_class"], name: "index_product_class_unique", unique: true
    t.index ["subscription_id"], name: "index_subscription_product_classes_on_subscription_id"
  end

  create_table "subscriptions", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "kind", null: false
    t.string "name", null: false
    t.string "regcode", null: false
    t.datetime "starts_at"
    t.string "status", null: false
    t.integer "system_limit", null: false
    t.integer "systems_count", null: false
    t.datetime "updated_at", null: false
    t.integer "virtual_count"
    t.index ["regcode"], name: "index_subscriptions_on_regcode"
  end

  create_table "system_uptimes", charset: "utf8mb4", collation: "utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "online_at_day", null: false
    t.binary "online_at_hours", limit: 24, null: false
    t.bigint "system_id", null: false
    t.datetime "updated_at", null: false
    t.index ["system_id", "online_at_day"], name: "id_online_day", unique: true
  end

  create_table "systems", charset: "utf8mb3", collation: "utf8mb3_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.text "instance_data"
    t.datetime "last_seen_at"
    t.string "login"
    t.string "password"
    t.boolean "proxy_byos", default: false
    t.integer "proxy_byos_mode", default: 0
    t.string "pubcloud_reg_code"
    t.datetime "registered_at"
    t.datetime "scc_registered_at"
    t.bigint "scc_system_id", comment: "System ID in SCC (if the system registration was forwarded; needed for forwarding de-registrations)"
    t.text "system_information", size: :long, collation: "utf8mb4_bin"
    t.string "system_token"
    t.datetime "updated_at", null: false
    t.index ["login", "password", "system_token"], name: "index_systems_on_login_and_password_and_system_token", unique: true
    t.index ["login", "password"], name: "index_systems_on_login_and_password"
    t.index ["system_token"], name: "index_systems_on_system_token"
    t.check_constraint "json_valid(`system_information`)", name: "system_information"
  end

  add_foreign_key "activations", "services", on_delete: :cascade
  add_foreign_key "activations", "subscriptions"
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
  add_foreign_key "system_uptimes", "systems"
end
