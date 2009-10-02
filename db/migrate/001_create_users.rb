####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class CreateUsers < ActiveRecord::Migration
   def self.up
      create_table :users do |t|
         t.column :login,                     :string
         t.column :email,                     :string
         t.column :crypted_password,          :string, :limit => 40
         t.column :salt,                      :string, :limit => 40
         t.column :created_at,                :datetime
         t.column :updated_at,                :datetime
         t.column :remember_token,            :string
         t.column :remember_token_expires_at, :datetime
         t.column :identity_url, :string
      end

      add_index :users, [ :login ]
   end

   def self.down
      drop_table :users
      drop_table :open_id_authentication_associations
      drop_table :open_id_authentication_nonces
      drop_table :open_id_authentication_settings
   end
end

