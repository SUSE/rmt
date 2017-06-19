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

ActiveRecord::Schema.define(version: 20170619104044) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

  create_table "products_repositories", force: :cascade do |t|
    t.integer "product_id"
    t.integer "repository_id"
    t.index ["product_id", "repository_id"], name: "index_products_repositories_on_product_id_and_repository_id", unique: true
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name"
    t.string "distro_target"
    t.string "description"
    t.boolean "enabled"
    t.boolean "autorefresh"
    t.boolean "installer_updates"
    t.string "external_url"
    t.index ["name", "distro_target"], name: "index_repositories_on_name_and_distro_target", unique: true
  end

  add_foreign_key "products_repositories", "products", on_delete: :cascade
  add_foreign_key "products_repositories", "repositories", on_delete: :cascade
end
