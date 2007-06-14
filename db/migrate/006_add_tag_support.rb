####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class AddTagSupport < ActiveRecord::Migration
   def self.up
      #Table for your Tags
      create_table :tags do |t|
         t.column :parent_id, :integer, :references => nil
         t.column :name, :string
         t.column :type, :string
	 t.column :data_id, :string, :references => nil
         t.column :data, :text
	 t.column :synonym, :text
      end

      create_table :taggings do |t|
         t.column :item_id, :integer
         t.column :tag_id, :integer
         t.column :tag_type, :string
      end

      # Index your tags/taggings
      add_index :tags, [ :name, :type]
      add_index :taggings, [:tag_id, :item_id]
   end

   def self.down
      drop_table :taggings
      drop_table :tags
   end
end

