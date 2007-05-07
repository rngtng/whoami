require 'active_record/fixtures' 

class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.column :name, :string, :limit => 50
      t.column :hashed_password, :string 
      t.column :salt, :string 
    end
    
    directory = File.join(File.dirname(__FILE__), "data")
    puts directory
    Fixtures.create_fixtures(directory, "users") 
  end

  def self.down
    User.delete_all  	  
    drop_table :users
  end
end
