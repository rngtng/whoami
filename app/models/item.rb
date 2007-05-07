class Item < ActiveRecord::Base
	belongs_to :account, :counter_cache => true
        serialize :data
        
        validates_presence_of :time
        validates_uniqueness_of :dataid
	
	
	def self.factory( type, *params )
	   class_name = type.capitalize + "Item"
	   raise unless defined? class_name.constantize
	   class_name.constantize.new( *params )
	end
	
	########### Data Functions ###########
	def url
		data.url
	end
	
	def title
	        data.title	
	end
	
	def text
		data.text
	end
	
	def info
		"Date: #{time.strftime("%Y-%m-%d")}\nTitle: #{title}\nText: #{text}\n"
	end

	def color 
		"#000000"
	end
	
	def thumbnail
	     return false unless data.thumbnail	
	     data.thumbnail
	end
	
	def type
	   self.class.to_s.downcase.sub( /item/, '' )
	end	
end

######################################################################################################

class FeedItem < Item
	def data=(d)
	  self.complete = true
	  self.dataid = d.id || d.urls.first
          self.time = d.date_published || Time.now
	  super(d)
        end
	
	def url
		data.urls.first
	end
	
	def thumbnail
	        "/images/accounts/feed.png"	
	end
	
	def color 
		"#9900FF"
	end
end

######################################################################################################

class FlickrItem < Item
	Struct.new( "MyPhoto", :url, :title, :text )
	
	def data=(d)
          self.time = d.dates[:taken] || d.dates[:posted]
	  self.complete = true
	  # add notes, comments, date_posted
	  d2 = Struct::MyPhoto.new( d.url, d.title, d.description )
	  #d2 = Hash.new( :url => d.url, :title => d.title, :text => d.description );
	  super(d2)
        end
	
	def thumbnail
	        data.url.sub( /\.jpg/, '_s.jpg')	
	end
	
	def info
		super +  "Comments:"  ##TODO: more info here!!
	end
	
	def color 
		"#FF0000"
	end
end

######################################################################################################

class YoutubeItem < Item
	def data=(d)
          self.dataid = d.id
          self.time = d.upload_time || Time.now
	  self.complete = true
	  super(d)
        end
	
	def thumbnail
	        data.thumbnail_url	
	end
	
	def text
		data.description
	end
	
	def info
             super +  "Comments:\nViews:\nVotes:\n" ###TODO more info here
	end
	
	def color 
		"#00FF00"
	end
end

######################################################################################################

class LastfmItem < Item
	def data=(d)
          self.dataid = d.url  ##TODO: is id available???
          self.time = d.date
	  self.complete = !d.album.nil?
	  super( d )
        end
	
	def text
		[data.artist, data.album.title].join("\n")
	end
	
	def title
		data.name
	end
	
	def info
		"Date: #{time.strftime("%Y-%m-%d")}\nTitle: #{title}\nArtist: #{artist}\nAlbum: #{album.title}\nPlayed: #{time.to_s}"
	end
	
	def thumbnail
		return "http://www.thumbshots.de/cgi-bin/show.cgi?url=http://www.last.fm" if album.nil?
		data.album.coverart['small']
	end
	
	def color 
		"#0000FF"
	end
	
	##############
	def artist
		data.artist
	end

	def album
		data.album
	end
	
        def album=(album)
		return if album.nil?
		data.album = album
		self.complete = true
        end	
end

######################################################################################################

class DeliciousItem < Item
	def data=(d)
          self.dataid = d.hash
          self.time = d.time
	  self.complete = true
	  super( d )
        end
	
	def url
		data.href
	end

        def title
               data.description
        end
	
	def text
               data.extended
        end
	
	def thumbnail
	      "http://www.thumbshots.de/cgi-bin/show.cgi?url=#{url}/.png"  #extension to get rid of deprecation warning	
	      #"http://open.thumbshots.org/image.pxf?url=#{data.url}"	
	end
	
	def color 
		"#00FFFF"
	end
end

######################################################################################################

class EbayItem < Item
        def data=(d)
          self.dataid = d.hash
          self.time = d.time
	  self.complete = true
	  super( d )
        end
	
	def url
		data.href
	end

        def title
               data.description
        end
	
	def text
               data.extended
        end
	
	def thumbnail
	end
	
	def color 
		"#FF00FF"
	end
end

######################################################################################################
class BlogItem < Item
        def data=(d)
          self.dataid = d['postid']
	  time = d['dateCreated'].to_time
	  return if time > Time.now #get rid of Furute posts
	  return unless time.to_i > 0  #get rid of Drafts
          self.time = time
	  self.complete = true
	  super( d )
        end
	
	def url
		data['permaLink']
	end

        def title
               data['title']
        end
	
	def text
               data['description']
        end
	
	def thumbnail
		"http://www.thumbshots.de/cgi-bin/show.cgi?url=#{url}/.png"  #extension to get rid of deprecation warning
	end
	
	def color 
		"#FF0099"
	end
end	
