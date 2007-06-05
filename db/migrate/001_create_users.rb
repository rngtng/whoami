class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table "users" do |t|
      t.column :login,                     :string
      t.column :email,                     :string
      t.column :crypted_password,          :string, :limit => 40
      t.column :salt,                      :string, :limit => 40
      t.column :created_at,                :datetime
      t.column :updated_at,                :datetime
      t.column :remember_token,            :string
      t.column :remember_token_expires_at, :datetime
      t.column :activation_code, :string, :limit => 40
      t.column :activated_at, :datetime
      t.column :identity_url, :string
    end
    
    add_index :users, [ :login ]
    
    create_table "open_id_authentication_associations" do |t|
      t.column "server_url", :binary
      t.column "handle", :string
      t.column "secret", :binary
      t.column "issued", :integer
      t.column "lifetime", :integer
      t.column "assoc_type", :string
    end

    create_table "open_id_authentication_nonces" do |t|
      t.column "nonce", :string
      t.column "created", :integer
    end

    create_table "open_id_authentication_settings" do |t|
      t.column "setting", :string
      t.column "value", :binary
    end
  end

  def self.down
    drop_table "users"
    drop_table "open_id_authentication_associations"
    drop_table "open_id_authentication_nonces"
    drop_table "open_id_authentication_settings"
  end
end

