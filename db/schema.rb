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

ActiveRecord::Schema[8.1].define(version: 2025_12_04_134558) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "contracts", force: :cascade do |t|
    t.string "agency", default: "other", null: false
    t.string "contract_type"
    t.decimal "cp_rate", precision: 4, scale: 2, default: "0.1", null: false
    t.datetime "created_at", null: false
    t.integer "fve_id"
    t.decimal "ifm_rate", precision: 4, scale: 2, default: "0.1", null: false
    t.decimal "km_limit", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "km_rate", precision: 5, scale: 2
    t.boolean "km_unlimited", default: false, null: false
    t.integer "merch_id"
    t.string "name", default: "", null: false
    t.decimal "night_rate", precision: 4, scale: 2, default: "0.5", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["fve_id", "merch_id"], name: "index_contracts_on_fve_id_and_merch_id", unique: true
    t.index ["fve_id"], name: "index_contracts_on_fve_id"
    t.index ["merch_id"], name: "index_contracts_on_merch_id"
    t.index ["user_id"], name: "index_contracts_on_user_id"
  end

  create_table "declarations", force: :cascade do |t|
    t.decimal "brut_with_cp", precision: 8, scale: 2, default: "0.0", null: false
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.string "employer_name", null: false
    t.integer "month", null: false
    t.string "status", default: "draft", null: false
    t.integer "total_minutes", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "year", null: false
    t.index ["contract_id"], name: "index_declarations_on_contract_id"
    t.index ["user_id", "year", "month"], name: "index_declarations_on_user_id_and_year_and_month"
    t.index ["user_id"], name: "index_declarations_on_user_id"
  end

  create_table "fve_invitations", force: :cascade do |t|
    t.string "agency"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at"
    t.boolean "premium", default: false, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.boolean "used", default: false, null: false
    t.index ["token"], name: "index_fve_invitations_on_token", unique: true
  end

  create_table "kilometer_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description", default: ""
    t.decimal "distance", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "km_rate", precision: 5, scale: 2, default: "0.29", null: false
    t.datetime "updated_at", null: false
    t.bigint "work_session_id", null: false
    t.index ["distance"], name: "index_kilometer_logs_on_distance"
    t.index ["work_session_id"], name: "index_kilometer_logs_on_work_session_id"
  end

  create_table "merch_settings", force: :cascade do |t|
    t.boolean "accept_mission_proposals", default: false, null: false
    t.boolean "allow_contact_email", default: false
    t.boolean "allow_contact_message", default: false
    t.boolean "allow_contact_phone", default: false
    t.boolean "allow_identity", default: false, null: false
    t.boolean "allow_none", default: false
    t.datetime "created_at", null: false
    t.string "preferred_contact_channel", default: "phone"
    t.boolean "role_anim", default: false
    t.boolean "role_merch", default: true
    t.boolean "share_address", default: false, null: false
    t.boolean "share_planning", default: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_merch_settings_on_user_id", unique: true
  end

  create_table "mission_proposals", force: :cascade do |t|
    t.string "agency", null: false
    t.string "company", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.decimal "effective_km", precision: 5, scale: 2
    t.datetime "end_time", null: false
    t.bigint "fve_id", null: false
    t.decimal "hourly_rate", precision: 5, scale: 2, default: "11.88"
    t.bigint "merch_id", null: false
    t.text "message"
    t.datetime "start_time", null: false
    t.string "status", default: "pending"
    t.string "store_address"
    t.string "store_name"
    t.datetime "updated_at", null: false
    t.index ["fve_id"], name: "index_mission_proposals_on_fve_id"
    t.index ["merch_id"], name: "index_mission_proposals_on_merch_id"
    t.index ["status"], name: "index_mission_proposals_on_status"
  end

  create_table "unavailabilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "date"], name: "index_unavailabilities_on_user_id_and_date", unique: true
    t.index ["user_id"], name: "index_unavailabilities_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "address"
    t.string "agency"
    t.string "city"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "firstname", default: "", null: false
    t.string "lastname", default: "", null: false
    t.string "phone_number"
    t.boolean "premium", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0
    t.datetime "updated_at", null: false
    t.string "username", default: "", null: false
    t.string "zipcode"
    t.index ["agency"], name: "index_users_on_agency"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "work_sessions", force: :cascade do |t|
    t.string "company"
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "duration_minutes", default: 0, null: false
    t.decimal "effective_km", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "end_time", null: false
    t.decimal "hourly_rate", precision: 5, scale: 2, default: "11.88", null: false
    t.decimal "km_custom", precision: 5, scale: 2
    t.integer "night_minutes", default: 0, null: false
    t.text "notes"
    t.boolean "recommended", default: false, null: false
    t.datetime "start_time", null: false
    t.integer "status", default: 0
    t.string "store"
    t.string "store_full_address"
    t.datetime "updated_at", null: false
    t.index ["contract_id"], name: "index_work_sessions_on_contract_id"
    t.index ["date"], name: "index_work_sessions_on_date"
  end

  add_foreign_key "contracts", "users"
  add_foreign_key "declarations", "contracts"
  add_foreign_key "declarations", "users"
  add_foreign_key "kilometer_logs", "work_sessions"
  add_foreign_key "merch_settings", "users"
  add_foreign_key "mission_proposals", "users", column: "fve_id"
  add_foreign_key "mission_proposals", "users", column: "merch_id"
  add_foreign_key "unavailabilities", "users"
  add_foreign_key "work_sessions", "contracts"
end
