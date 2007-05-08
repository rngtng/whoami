class CreateCachedalbums < ActiveRecord::Migration
  def self.up
    create_table :cachedalbums do |t|
      t.column :artist,       :string
      t.column :title,        :string
      t.column :album,        :text
    end
  end

  def self.down
    drop_table :cachedalbums
  end
end
