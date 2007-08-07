####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class CreateResources < ActiveRecord::Migration
   def self.up
      create_table :resources do |t|
         t.column :account_id, :integer
         t.column :type,       :string
         t.column :time,       :datetime
         t.column :data_id,     :string, :references => nil
         t.column :data,       :text
         t.column :complete,   :boolean, :default => false
      end

      add_index :resources, [ :account_id, :type]

   end

   def self.down
      drop_table :resources
   end
end

