class Item < ActiveRecord::Base
	acts_as_taggable
	
	belongs_to :account, :include => :user, :counter_cache => true
	delegate :user, :to => :account
	
        serialize  :data
        
        validates_presence_of :time
	validates_presence_of :dataid
        validates_uniqueness_of :dataid, :scope => 'account_id'
		
	attr_reader :images, :links
	
	def self.factory( type, *params )
	   class_name = type.capitalize + "Item"
	   raise unless defined? class_name.constantize
	   class_name.constantize.new( *params )
	end
	
	#callback
	def after_find
		parse_data
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
		"Id: #{id}\nDate: #{time.strftime("%Y-%m-%d")}\nTitle: #{title}\nText: #{text}\nTags: #{tag_list}\nLinks: #{@links.join(', ')}\nImages: #{@images.join(', ')}\n"
	end

	def color 
		"#000000"
	end
	
	def thumbnail
	     thumbshot( url)
	end
	
	def type
	   self.class.to_s.downcase.sub( /item/, '' )
	end	
	
	def html
		false
	end
	
	###############################################################################################
	def get_relation_by_link
		l = links.compact << url
		get_relation( l )
	end	
	
	def get_relation_by_image
		i= images.compact
		get_relation( i )
	end
	
	def get_relation_by_tag
		return [] if self.tags.empty?
		h = user.valid_items.find_tagged_with( self.tags.compact )
		user.valid_items.find( :all, h )
	end
	
	def get_relation_to_items_after( period = 2.days ) #future
		get_relation_by_period( time, time + period )
	end
	
	def get_relation_to_items_before( period = 2.days)  #past
		get_relation_by_period( time - period, time )
	end
	
	def get_relation_by_period( from, to )
		user.valid_items.find( :all, :conditions => [ "items.time >= ? AND items.time <= ?", from, to ] )
	end
	
	###############################################################################################
	
	private
	def get_relation( type )
		return [] unless type.size > 0
		type.map! do |t|
		   t = $1 if t =~ /flickr.*\/([^\/]*)$/ #strip that flickr stuff!!
		   "%#{t}%"; 
		end
		c = Array.new( type.size, "items.data LIKE ?" )
		user.valid_items.find( :all, :conditions => [ "items.id != ? AND (#{c.join( ' OR ')})", self.id, *type])
	end
	
	def thumbshot( u )
		"http://www.thumbshots.de/cgi-bin/show.cgi?url=#{u}/.png"
	end	
	
	def parse_data
	      @images = Array.new
	      @links  = Array.new
	      return unless complete
	      return unless text
	      d = text.gsub( / www\./, ' http://www.').gsub( /'"/, '')
	      URI::extract( d, 'http' ) do |url|
	         if url =~ /\.(png|jpg|gif)/
	      	   @images << url
	      	   next
	         end
	         @links << url
	      end
	end
	
	#def html_entities( string )
	#	string.unpack("U*").collect {|s| (s > 127 ? "&##{s};" : s.chr) }.join("")
	#	string.gsub( /ä/, "&auml;" ).gsub( /Ä/, "&Auml;" ).
        #        gsub( /ö/, "&ouml;" ).gsub( /Ö/, "&Ouml;" ).
        #       gsub( /ü/, "&uuml;" ).gsub( /Ü/, "&Uuml;" )
	#end	
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
		return @images.first if @images.first
		return thumbshot( @links.first ) if @links.first
		super  #extension to get rid of deprecation warning
	end
	
	def color 
		"#9900FF"
	end
end

######################################################################################################

class FlickrItem < Item
	Struct.new( "MyPhoto", :url, :title, :text ) unless defined? Struct::MyPhoto
	
	def data=(d)
	   return super(d) if self.dataid	
	   self.dataid = [d.id, d.secret].join(':')
	   self.time = Time.now 
	end	
		
	def data_add( d )
          self.time = d.dates[:taken] || d.dates[:posted]
	  self.complete = true
	  add_tags( d.tags )
	  # add notes, comments, date_posted
	  d2 = Struct::MyPhoto.new( d.url, d.title, d.description )
	  #d2 = Hash.new( :url => d.url, :title => d.title, :text => d.description );
	  self.data = d2
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
	
	private
	def add_tags( tags )
		tags.each do |tag|
		     self.tag( tag.clean )
		end
	end
	
	def parse_data
		super
		@images << data.url if data
	end	
end

######################################################################################################

class YoutubeItem < Item
	def data=(d)
          self.dataid = d.id
          self.time = d.upload_time || Time.now
	  self.complete = true
	  Tag.delimiter = ' '
	  self.tag_list = d.tags.downcase
	  super(d)
        end
	
	def thumbnail
	        data.thumbnail_url	
	end
	
	def text
		data.description
	end
	
	def info
		super +  "Lengths:#{data.length_seconds}\nComments:#{data.comment_count}\n" +
		"Views:#{data.view_count}\nRating:#{data.rating_avg}\n" +
		"Votes:#{data.rating_count}\n" ###TODO more info here
	end
			
	def color 
		"#00FF00"
	end
	
	def html(width = 425, height = 350)
	   data.embed_html(width, height )
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
		return thumbshot( 'http://www.last.fm' ) if album.nil?
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
	  Tag.delimiter = ' '
	  self.tag_list = d.tag.downcase
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
	
	def color 
		"#0000dd"
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
		return @images.first if @images.first
		return thumbshot( @links.first ) if @links.first
		super  #extension to get rid of deprecation warning
	end
	
	def color 
		"#FF0099"
	end
	
	#private
	#a.items.each do | i | i.get_tags; i.save; end
	#def get_tags
	#   t = text.gsub( /&/, 'und' ).gsub( /[^a-zA-Z0-9 ] /, ' ')
	#   tags = [ 'b', 'i', 'strong', 'em' ]	
 	#   resp = XmlSimple.xml_in( "<html>#{t}</html>", { 'ForceArray' => tags })
	#   r = title
	#   tags.each do | t |
	#     r = [ r, resp[t] ].join( ' ') if resp[t]
	#   end
	#   Tag.delimiter = ' '
	#   self.tag_list = r
	#end
end	

######################################################################################################

class YahoosearchItem < Item

        def data=(d)
          self.dataid = d['Url']
	  self.time = Time.at( d['ModificationDate'].to_i )
	  self.complete = true
	  super( d )
        end
	
	def url
	    data['Url']	
	end
	
	def title
               data['Title']
        end
	
	def text
               data['Summary']
        end
	
	def info
		super
	end
	
	def color 
		"#99FF33"
	end
end

######################################################################################################

class TwitterItem < Item

        def data=(d)
          self.dataid = d.id
	  self.time = d.created_at
	  self.complete = true
	  super( d )
        end
	
	def url
		"http://www.twitter.com/#{data.user.screen_name}/statuses/#{data.id}"
	end
	
	def title
		"#{data.user.name} says"
        end
	
	def text
               data.text
        end
	
	def thumbnail
		return @images.first if @images.first
		return thumbshot( @links.first ) if @links.first
		super  #extension to get rid of deprecation warning
	end
	
	def info
		super
	end
	
	def color 
		"#9BE5E9"
	end
end
