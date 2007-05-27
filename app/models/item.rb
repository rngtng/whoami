class Item < ActiveRecord::Base
	belongs_to :account, :include => :user #, :counter_cache => true
	
	delegate :user, :color,        :to => :account
	delegate :url, :title, :text,  :to => :data
	
	@tag_types = :images, :locations, :links, :notes, :people 
	
	has_many_polymorphs :tags, :through => :taggings, :from =>  @tag_types
	
        serialize  :data               
        
        validates_presence_of   :time
	validates_presence_of   :dataid
        validates_uniqueness_of :dataid, :scope => 'account_id' #we need that for testing if item is allready in DB
	
        after_save :save_tags                         
	
	def self.factory( type, *params )
	   class_name = type.capitalize + "Item"
	   raise unless defined? class_name.constantize 
	   class_name.constantize.new( *params )
	end                                                                                                       
	
	def self.tags( options = {} )
	    scope = scope(:find)
	    cond = ["1"]
            cond << sanitize_sql(scope.delete(:conditions)) if scope && scope[:conditions]
            cond << sanitize_sql(options.delete(:conditions)) unless options[:conditions].nil?
	    cond << sanitize_sql( [ 'tags.type = ?', options.delete(:type) ] ) unless options[:type].nil?
  
	    join = []
	    join << scope[:joins] if scope && scope[:joins]
	    join << "LEFT OUTER JOIN taggings ON taggings.item_id = items.id"
	    join << "LEFT OUTER JOIN tags ON taggings.tag_id = tags.id"
	    
	    Tag.find( :all,
	              :from => 'items',
	              :select => 'tags.*, COUNT(tags.id) count',
	              :joins => join.join( ' ' ),
		      :conditions => cond.join( ' AND ' ),		 
	              :group => "taggings.tag_id" )
	end
	
	def self.set_tag_types( tag_types )  # Add a new methods to the class.
	      tag_types.each do |tag|	
		class_eval %{ 
		  def self.#{tag.to_s}
                      self.tags( :type => "#{tag.to_s.classify}" )
                   end
		}
	      end	
	end
	set_tag_types @tag_types
	
	def self.tag_types
		@tag_types.map #return copy!
	end	
	
	###############################################################################################
	def info
		"Id: #{id}\nDate: #{time.strftime("%Y-%m-%d")}\nTitle: #{title}\nText: #{text}\n"
		#TODO + "Tags: #{meta.to_s}\nLinks: #{links.to_s}\nImages: #{images.to_s}\nPeople: #{people.to_s}\nLocations: #{locations.to_s}"
	end

	def thumbnail
	     thumbshot( url)
	end

	def type
	     self.class.to_s.downcase.sub( /item/, '' )
	end	
	
	#html code to diplay instead fo default code
	def html( width = 50, height = 50 )
		false
	end
	
	###############################################################################################
        def tag( tag, split_by = nil )  #can be a Sting, a Hash where :Tagtype => TagName or a tag        
		@cached_tags ||= []
		tag = Tag.get( tag, split_by )  unless tag.is_a? Tag
		@cached_tags  <<  tag
	end                                  
	                       
	def save_tags  
		tags << @cached_tags if @cached_tags
	end	
	###############################################################################################
	def get_relation_by_link
		
		[] #l = links.compact << url
		#get_relation( l )
	end	
	
	def get_relation_by_image
		[] #i= images.compact
		#get_relation( i )
	end
	
	def get_relation_by_tag
		[]
		#return [] if self.tags.empty?
		#h = user.valid_items.find_tagged_with( self.tags.compact )
		#user.valid_items.find( :all, h )
	end
	
	def get_relation_to_items_after( period = 2.days ) #future
		get_relation_by_period( time, time + period )
	end
	
	def get_relation_to_items_before( period = 2.days)  #past
		get_relation_by_period( time - period, time )
	end
	
	def get_relation_by_period( from, to )
		user.valid_items.find( :all, :conditions => [ "items.id != ? AND items.time >= ? AND items.time <= ?", self.id, from, to ] )
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
	
	def thumbshot( url )
		"http://www.thumbshots.de/cgi-bin/show.cgi?url=#{url}/.png"  #add /.png to get rif of error ms
	end	
	
	######################################################################################################
        def extract_all  #finds tags, people and locations
		extract_links_and_images
		extract_meta_people_locations
	end	
	
	def extract_links_and_images( from = nil ) #finds links_and_images
	      from = text unless from	
	      d = from.gsub( / www\./, ' http://www.').gsub( /'"/, '')
	      URI::extract( d, 'http' ) do |url|
	         type = ( url =~ /\.(png|jpg|gif)/ ) ? :image : :link
		 tag( type => url )
	      end
	end
	        
        def tag_the_net( from_url = nil  )                
		from_url = ( url ) ? "url=#{from_url}" : "text=#{CGI::escape(text)}" 
	        doc = Hpricot.XML( open( "http://tagthe.net/api/?#{from_url}" ) )     
		(doc/"dim[@type='topic']/item").each    { |item| tag( item.inner_html ) } # return all gerneral tags
		(doc/"dim[@type='person']/item").each   { |item| tag( :person => item.inner_html ) } # return all people
		(doc/"dim[@type='location']/item").each { |item| tag( :location => item.inner_html ) } # return all locations
		#(doc/"dim[@type='language']/item").each # return all people
		#(doc/"dim[@type='author']/item").each # return all people
		#(doc/"dim[@type='title']/item").each # return all people 
	end	
	alias extract_meta_people_locations tag_the_net
end

######################################################################################################
class FeedItem < Item
	@color = "#9900FF"
	def data=(d)
	  self.dataid = d.id || d.urls.first
          self.time = d.date_published || Time.now
	  super(d)
	  tag( :link => url )
	  extract_all
	  self.complete = true
        end
	
	def url
		data.urls.first
	end
	
	def thumbnail
		#return @images.first if @images.first
		#return thumbshot( @links.first ) if @links.first
		super  #extension to get rid of deprecation warning
	end
end

######################################################################################################
class FlickrItem < Item
	##TODO is url correct?????
	Struct.new( "MyPhoto", :url, :title, :text ) unless defined? Struct::MyPhoto ##TODO get rid of this stupid struct!!!
	
	def data=(d)
	   return super(d) if self.dataid	
	   self.dataid = [d.id, d.secret].join(':')
	   self.time = Time.now
	end	
		
	def data_add( d )
          self.time = d.dates[:taken] || d.dates[:posted]
	  d.tags.each do |tag|
	    tag( tag.clean )
	  end  
	  # add notes, comments, date_posted
	  d2 = Struct::MyPhoto.new( d.url, d.title, d.description )
	  #d2 = Hash.new( :url => d.url, :title => d.title, :text => d.description );
	  self.data = d2
	  tag( :image => url )
	  self.complete = true
        end
	
	def geotag( d )
		
	end
	
	def thumbnail
	        data.url.sub( /\.jpg/, '_s.jpg')	
	end
	
	def info
		super +  "Comments:"  ##TODO: more info here!!
	end
	
	def imgid
	     @imgid, @secret = dataid.split(/:/) unless @imgid
	     @imgid
	end     
	
	def secret
	     imgid unless @secret
	     @secret
	end
end

######################################################################################################
class YoutubeItem < Item
	def data=(d)
          self.dataid = d.id
          self.time = d.upload_time || Time.now
	  tag( d.tags, ' ')
	  super(d)
	  tag( :link => url )
	  self.complete = true
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
			
	def html(width = 425, height = 350)
	   data.embed_html(width, height )
	end   
end

######################################################################################################
class LastfmItem < Item
	delegate :artist, :to => :data
	delegate :album,  :to => :data
	
	def data=(d)
          self.dataid = d.url  ##TODO: is id available???
          self.time = d.date
	  super( d )
	  self.complete = !album.nil?
        end
	
	def text
		[data.artist, data.album.title].join("\n")
	end
	
	def info
		"Date: #{time.strftime("%Y-%m-%d")}\nTitle: #{title}\nArtist: #{artist}\nAlbum: #{album.title}\nPlayed: #{time.to_s}"
	end
	
	def thumbnail
		return thumbshot( 'http://www.last.fm' ) if album.nil?
		data.album.coverart['small']
	end
	
	##############
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
	  tag( d.tag, ' ' )
	  super( d )
	  tag( :link => url)
	  self.complete = true
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
	  super( d )  
	  extract_all
	  tag( :link => url)
	  self.complete = false
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
		#return @images.first if @images.first
		#return thumbshot( @links.first ) if @links.first
		super  #extension to get rid of deprecation warning
	end
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
end

######################################################################################################
class TwitterItem < Item
        def data=(d)
          self.dataid = d.id
	  self.time = d.created_at
	  super( d )
	  self.complete = true
        end
	
	def url
		"http://www.twitter.com/#{data.user.screen_name}/statuses/#{data.id}"
	end
	
	def title
		"#{data.user.name} says"
        end
	
	def thumbnail
		#return @images.first if @images.first
		#return thumbshot( @links.first ) if @links.first
		super  #extension to get rid of deprecation warning
	end
	
	def info
		super
	end
end

######################################################################################################
class PlazesItem < Item
	delegate :plaze,    :to => :data
	delegate :street,   :to => :plaze
	delegate :zip,      :to => :plaze
	delegate :city,     :to => :plaze
	delegate :country,  :to => :plaze
	delegate :latitude, :to => :plaze
	delegate :longitude,:to => :plaze
	delegate :blog_url, :to => :plaze
	
	def data=(d)
	  return unless d.plaze.name	
	  self.time = d.start.to_time
	  self.dataid = "#{d.plaze.key}#{self.time.to_i}"
	  super( d )
	  #extract_all
	  extract_meta_people_locations( url )
	  self.complete = true  
        end
	
	def url
		return "http://#{plaze.blog_url.gsub( 'http://', '')}" unless plaze.blog_url.empty?
		plaze.url
	end
	
	def title
		plaze.name
        end
	
	def text
		"#{street} #{zip} #{city} #{country}\n Latitude: #{latitude} Longitude: #{longitude}\n #{blog_url}"
        end
end	


############################################################################################################################################


	
	#def thumbnail
#		return @images.first if @images.first
		#return thumbshot( @links.first ) if @links.first
		#super  #extension to get rid of deprecation warning
	#end
	
	#def info
#		super
#	end


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
