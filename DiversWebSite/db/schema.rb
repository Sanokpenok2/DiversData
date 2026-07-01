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

ActiveRecord::Schema[8.1].define(version: 2026_06_28_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "favorites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "report_id", null: false
    t.bigint "scientist_id", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_favorites_on_report_id"
    t.index ["scientist_id", "report_id"], name: "index_favorites_on_scientist_id_and_report_id", unique: true
    t.index ["scientist_id"], name: "index_favorites_on_scientist_id"
  end

  create_table "registration_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.datetime "expires_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "used_by_id"
    t.index ["created_by_id"], name: "index_registration_tokens_on_created_by_id"
    t.index ["token"], name: "index_registration_tokens_on_token", unique: true
    t.index ["used_by_id"], name: "index_registration_tokens_on_used_by_id"
  end

  create_table "report_deletion_requests", force: :cascade do |t|
    t.text "admin_note"
    t.datetime "created_at", null: false
    t.text "reason", null: false
    t.integer "report_id", null: false
    t.bigint "requested_by_id", null: false
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id"], name: "index_report_deletion_requests_on_report_id"
    t.index ["requested_by_id"], name: "index_report_deletion_requests_on_requested_by_id"
    t.index ["reviewed_by_id"], name: "index_report_deletion_requests_on_reviewed_by_id"
    t.index ["status"], name: "index_report_deletion_requests_on_status"
  end

  create_table "report_photos", id: :integer, default: nil, force: :cascade do |t|
    t.text "attachment_token", null: false
    t.text "caption"
    t.datetime "created_at", precision: nil, null: false
    t.text "photo_type", null: false
    t.integer "report_id", null: false
    t.text "source_url"
    t.text "storage_path"
    t.index ["report_id"], name: "report_photos_report_id_index"
  end

  create_table "reports", id: :integer, default: nil, force: :cascade do |t|
    t.text "additional_info"
    t.datetime "created_at", precision: nil, null: false
    t.boolean "depth_is_approximate", default: true, null: false
    t.float "depth_m", null: false
    t.float "encounter_radius_m"
    t.text "encounter_type", null: false
    t.float "latitude"
    t.text "location_description"
    t.text "location_type", null: false
    t.float "longitude"
    t.text "max_first_name"
    t.text "max_last_name"
    t.bigint "max_user_id", null: false
    t.text "max_username"
    t.date "observation_date", null: false
    t.text "status", default: "submitted", null: false
    t.text "substrate_type", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["created_at"], name: "reports_created_at_index"
    t.index ["max_user_id"], name: "reports_telegram_user_id_index"
    t.index ["observation_date"], name: "reports_observation_date_index"
  end

  create_table "schema_info", id: false, force: :cascade do |t|
    t.integer "version", default: 0, null: false
  end

  create_table "scientists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "scientist", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_scientists_on_email", unique: true
    t.index ["role"], name: "index_scientists_on_role"
  end

  create_table "user_sessions", id: :integer, default: nil, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.jsonb "data", default: {}, null: false
    t.bigint "max_user_id", null: false
    t.text "state", default: "idle", null: false
    t.datetime "updated_at", precision: nil, null: false

    t.unique_constraint ["max_user_id"], name: "user_sessions_telegram_user_id_key"
  end

  add_foreign_key "favorites", "scientists"
  add_foreign_key "registration_tokens", "scientists", column: "created_by_id"
  add_foreign_key "registration_tokens", "scientists", column: "used_by_id"
  add_foreign_key "report_deletion_requests", "reports", on_delete: :cascade
  add_foreign_key "report_deletion_requests", "scientists", column: "requested_by_id"
  add_foreign_key "report_deletion_requests", "scientists", column: "reviewed_by_id"
  add_foreign_key "report_photos", "reports", name: "report_photos_report_id_fkey", on_delete: :cascade
end
