# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170824112223) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "activations", force: :cascade do |t|
    t.integer "service_id", null: false
    t.integer "system_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_predecessors", force: :cascade do |t|
    t.integer "product_id"
    t.integer "predecessor_id"
    t.index ["product_id", "predecessor_id"], name: "index_product_predecessors_on_product_id_and_predecessor_id", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "description"
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
    t.boolean "available"
    t.string "cpe"
  end

  create_table "products_extensions", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "extension_id", null: false
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.boolean "enabled", default: false, null: false
    t.boolean "autorefresh", default: true, null: false
    t.string "external_url", null: false
    t.string "auth_token"
    t.boolean "installer_updates", default: false, null: false
    t.boolean "mirroring_enabled", default: false, null: false
    t.string "local_path", null: false
    t.index ["external_url"], name: "index_repositories_on_external_url", unique: true
  end

  create_table "repositories_services", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.integer "service_id", null: false
    t.index ["service_id", "repository_id"], name: "index_repositories_services_on_service_id_and_repository_id", unique: true
  end

  create_table "services", force: :cascade do |t|
    t.integer "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_services_on_product_id", unique: true
  end

  create_table "subscription_product_classes", force: :cascade do |t|
    t.integer "subscription_id", null: false
    t.string "product_class", null: false
    t.index ["subscription_id", "product_class"], name: "index_product_class_unique", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
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
  end

  create_table "systems", force: :cascade do |t|
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

  add_foreign_key "activations", "systems", on_delete: :cascade
  add_foreign_key "product_predecessors", "products", on_delete: :cascade
  add_foreign_key "products_extensions", "products", column: "extension_id", on_delete: :cascade
  add_foreign_key "products_extensions", "products", on_delete: :cascade
  add_foreign_key "repositories_services", "repositories", on_delete: :cascade
  add_foreign_key "repositories_services", "services", on_delete: :cascade
  add_foreign_key "subscription_product_classes", "subscriptions", on_delete: :cascade
end
