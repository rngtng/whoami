# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 7) do

  create_table "accounts", :force => true do |t|
    t.integer  "user_id"
    t.string   "type"
    t.string   "username",        :limit => 20
    t.string   "password",        :limit => 20
    t.string   "host",            :limit => 100
    t.text     "token"
    t.integer  "resources_count",                :default => 0
    t.datetime "updated_at"
  end

  add_index "accounts", ["user_id", "type", "resources_count", "updated_at"], :name => "index"

  create_table "annotatings", :force => true do |t|
    t.integer "resource_id"
    t.integer "annotation_id"
    t.string  "annotation_type"
  end

  add_index "annotatings", ["annotation_id", "resource_id"], :name => "index_annotatings_on_annotation_id_and_resource_id"

  create_table "annotations", :force => true do |t|
    t.integer "parent_id"
    t.string  "name"
    t.string  "type"
    t.string  "data_id"
    t.text    "data"
    t.text    "synonym"
  end

  add_index "annotations", ["name", "type"], :name => "index_annotations_on_name_and_type"

  create_table "cachedalbums", :force => true do |t|
    t.string "artist"
    t.string "title"
    t.text   "album"
  end

  create_table "open_id_authentication_associations", :force => true do |t|
    t.binary  "server_url"
    t.string  "handle"
    t.binary  "secret"
    t.integer "issued"
    t.integer "lifetime"
    t.string  "assoc_type"
  end

  create_table "open_id_authentication_nonces", :force => true do |t|
    t.string  "nonce"
    t.integer "created"
  end

  create_table "open_id_authentication_settings", :force => true do |t|
    t.string "setting"
    t.binary "value"
  end

  create_table "resources", :force => true do |t|
    t.integer  "account_id"
    t.string   "type"
    t.datetime "time"
    t.string   "data_id"
    t.text     "data"
    t.boolean  "complete",   :default => false
    t.string   "thumbnail"
    t.string   "title"
    t.text     "text"
    t.string   "url"
  end

  add_index "resources", ["account_id", "type"], :name => "index_resources_on_account_id_and_type"

  create_table "sessions", :force => true do |t|
    t.string   "session_id"
    t.text     "data"
    t.datetime "updated_at"
  end

  add_index "sessions", ["session_id"], :name => "index_sessions_on_session_id"
  add_index "sessions", ["updated_at"], :name => "index_sessions_on_updated_at"

  create_table "users", :force => true do |t|
    t.string   "login"
    t.string   "email"
    t.string   "crypted_password",          :limit => 40
    t.string   "salt",                      :limit => 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "remember_token"
    t.datetime "remember_token_expires_at"
    t.string   "identity_url"
  end

  add_index "users", ["login"], :name => "index_users_on_login"

end
