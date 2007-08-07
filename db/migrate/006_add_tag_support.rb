####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class AddAnnotationSupport < ActiveRecord::Migration
   def self.up
      #Table for your Annotations
      create_table :annotations do |t|
         t.column :parent_id, :integer, :references => nil
         t.column :name, :string
         t.column :type, :string
	 t.column :data_id, :string, :references => nil
         t.column :data, :text
	 t.column :synonym, :text
      end

      create_table :annotatings do |t|
         t.column :resource_id, :integer
         t.column :annotation_id, :integer
         t.column :annotation_type, :string
      end

      # Index your annotations/annotatings
      add_index :annotations, [ :name, :type]
      add_index :annotatings, [:annotation_id, :resource_id]
   end

   def self.down
      drop_table :annotatings
      drop_table :annotations
   end
end

