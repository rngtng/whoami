class AddThumbnailColumn < ActiveRecord::Migration
   def self.up
      add_column :resources, :thumbnail, :string
      add_column :resources, :title,      :string
      add_column :resources, :text,       :text
      add_column :resources, :url,        :string

      Resource.find( :all ).each  do |resource|
         resource.text      = resource.text
	 resource.title     = resource.title
	 resource.url       = resource.url
         resource.thumbnail = resource.thumbnail
         resource.save
      end
   end

   def self.down
      remove_column :resources, :thumbnail
      remove_column :resources, :title
      remove_column :resources, :text
      remove_column :resources, :url
   end
end

