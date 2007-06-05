class CreateAccounts < ActiveRecord::Migration
  def self.up
    create_table :accounts do |t|
      t.column :user_id,        :integer
      t.column :type,           :string
      t.column :username,       :string,  :limit => 20
      t.column :password,       :string,  :limit => 20
      t.column :host,           :string,  :limit => 100
      t.column :token,          :text
      #t.column :items_count,    :integer, :default => 0
      t.column :updated_at,     :datetime
    end
  end

  add_index :accounts, [ :user_id, :type, :updated_at]
  
  def self.down
    drop_table :accounts
  end
end
