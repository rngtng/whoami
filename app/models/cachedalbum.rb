class Cachedalbum < ActiveRecord::Base
	serialize :album
	
	validates_presence_of :artist
	validates_presence_of :title
	
	validates_uniqueness_of :title, :scope => "artist"
	
	def tracks
		album.tracks
	end
end
