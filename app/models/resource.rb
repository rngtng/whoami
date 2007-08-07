####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

# Class representing an item
#-- require 'tag'
class Item < ActiveRecord::Base
   belongs_to :account  #, :counter_cache => true

   delegate :user,                :to => :account
   delegate :url, :title, :text,  :to => :data

   has_many_polymorphs :tags, :through => :taggings, :from =>  Tag.types

   serialize  :data

   validates_associated    :account
   validates_presence_of   :time
   validates_presence_of   :data_id
   validates_uniqueness_of :data_id, :scope => 'account_id' #we need that to check if item is allready in DB

   after_save :save_tags

   #Returns Items subclass of type type
   def self.factory( type, *params )
      class_name = type.capitalize + "Item"
      raise unless defined? class_name.constantize
      class_name.constantize.new( *params )
   end

   #Tags of the items
   def self.tags( options = {} )
      opt = prepage_query( options )
      opt[:from]   = 'items'
      opt[:select] = 'tags.*, COUNT(tags.id) count'
      opt[:group]  = 'tags.id'
      Tag.find( :all, opt )
   end

   #Find items tagged with the given options. This can be:
   #  * :account_id => ID - only items from a specific account
   #  * :from => time - items not older than time
   #  * :to => time - items not younger then time
   #  * :time => time - items not older than time
   #  * :period => timespan - items not younger then time + period
   #  * :tag => name - items which match this tag
   #  * :tags => array of names - items which match a least one of the tags
   #  * :TAGTYPE => name
   def self.find_tagged_with( options = {})
      opt = prepage_query( options, 'ftw' )  #set uniqe identifier -ftw- to be able to extend query...
      scope( :find )[:select] = 'items.*, COUNT(items.id) as count'
      opt[:group]  = 'items.id HAVING count > 0'
      #opt[:having]  = 'count > 0'
      #puts '##############################'
      #pp opt
      #pp scope( :find )
      result = Item.find( :all, opt )
      return result unless @tag_types
      result.instance_variable_set( :@options, opt )
      #add some helpfull methods to array
      @tag_types.each do |tag|
         result.instance_eval <<-end_eval
         def #{tag.to_s}
            Item.#{tag.to_s}( @options.merge( {} ) )
         end
         end_eval
      end
      return result
   end

   #Returns an array of items as iCal Format
   def self.to_calendar( items )
      cal = Icalendar::Calendar.new
      cal.custom_property("METHOD","PUBLISH")
      items.each do |i|
         cal.add_event( i.to_event )
      end
      cal
   end

   # Find oldest items
   def self.min_time
      scope(:find)[:select] = 'MIN(items.time) AS time'
      Item.find( :first ).time
   end

   # Find youngest (lastest) items
   def self.max_time
      scope(:find)[:select] = 'MAX(items.time) AS time'
      Item.find( :first ).time
   end

   # List of tag types
   def self.tag_types
      @tag_types
   end

   # Add a dynamic methods to class for getting tags for all items
   def self.tag_types=( tag_types )
      @tag_types = tag_types
      @tag_types.each do |tag|
         class_eval <<-end_eval
         def self.#{tag.to_s}( options = {} )
            options[:type] = "#{tag.to_s.classify}"
            tags( options )
         end
         end_eval
      end
   end
   self.tag_types = Tag.types

   # Condition for a valid item
   def self.valid_condition( valid = true)
      [ 'items.complete = ?', valid  ]
   end

   ###############################################################################################
   # Complete info of an item
   def info
      info = ["Id:    #{id}"]
      info << "Date:  #{time.strftime('%Y-%m-%d')}"
      info << "Title: #{title}"
      info << "Text:  #{text}"
      self.class.superclass.tag_types.each do |tag|
         tag = tag.to_s
         tags = send( tag ).join(', ')
         info << "#{tag.capitalize}: #{tags}" unless tags.empty?
      end
      info << "----------\n"
      info.join("\n")
   end

   # Returns thumbnail. If available the first tagged image is returned, if not thumbshot of the first
   # link, if this fails to, the thumbshot of url is taken
   def thumbnail
      return images.first.thumbnail unless images.empty?
      return thumbshot( links.first.thumbnail ) unless links.empty?
      thumbshot( url)
   end

   # Returns item as iCal event
   def to_event
      event = Icalendar::Event.new
      event.dtstart = time.strftime("%Y%m%dT%H%M%S")
      event.summary = title
      event.url = url
      event.description = text
      event.categories = [type]
      #event.related_to
      event.geo =   Icalendar::Geo.new( geos.first.lat, geos.first.lng ) unless geos.empty?
      event.location = locations.map!( &:name).join(',' )
      #event contacts
      #event.klass = "PUBLIC"
      #event.attachment
      event
   end

   # Type of the item
   def type
      @type ||= self.class.to_s.downcase.sub( /item/, '' )
   end

   # Html code to diplay instead fo default code
   def html( width = 50, height = 50 )
      false
   end

   # Get the account color for the item.
   def color #much faster than delegte to account.color!
      "#{type}_account".classify.constantize.color
   end

   ###############################################################################################
   # Tags item with tag. If split_by is provided, tag is splited in server tags
   # tag can be a Sting, a Hash where :Tagtype => TagName or a Tag
   def tag( tag, split_by = nil )
      @cached_tags ||= []
      tag = Tag.split_and_get( tag, split_by )  unless tag.is_a? Tag
      @cached_tags  <<  tag
   end

   # Save tags
   def save_tags
      tags << @cached_tags if @cached_tags
   end

   # Set item data taken from a feed entry
   def feed=(f)
      self.data_id = f.id || f.urls.first
      self.time = f.date_published || Time.now
      self.data = SimpleItem.new( :url => f.url, :title => f.title,  :text => f.description )
      tag( :link => url ) #TDODO specify better type here?
      extract_all
      self.complete = true
   end

   # Get related items. This can be via:
   # * tags:
   # * time:
   def related_items( options = {} )
      options[:time] = time if options[:period] && !options[:time]
      options[:conditions] = ["items.id !=? AND items.complete=1", id ]
      options[:having] = "cnt > 2"
      account.user.items.find_tagged_with( options )
   end

   ###############################################################################################
   private
   # Prepares the query for finding tags and tagged items
   #--
   # TODO :location => 'esa' should work to
   def self.prepage_query( options = {}, nr = '')	# eg. :tag => 'esa' :type - :account_id - :period, :time
      scope = scope(:find)
      cond = ["1"]
      cond << sanitize_sql(scope.delete(:conditions)) if scope && scope[:conditions]
      cond << sanitize_sql(options.delete(:conditions)) if options[:conditions]
      cond << sanitize_sql( ['items.account_id=?', options.delete(:account_id) ] ) if options[:account_id]

      if options[:from] and options[:to]
         options[:time] = options.delete(:from )
         options[:period] = options.delete(:to ).to_i - options[:time].to_i
      end
      if options[:time]
         period = ( options[:period] ) ?  options.delete(:period) : 2.days
         past   = ( period <  0 ) ? period : 0
         future = ( period >= 0 ) ? period : 0
         time   = Time.at( options.delete(:time).to_i )
         cond << sanitize_sql( [ "items.time >= ? AND items.time <= ?", time+past, time+future ] )
      end

      join = []
      join << scope.delete(:joins) if scope && scope[:joins]
      join << options.delete(:joins) if options[:joins]
      join << "INNER JOIN taggings AS taggings#{nr} ON taggings#{nr}.item_id = items.id"
      join << "INNER JOIN tags     AS tags#{nr}     ON tags#{nr}.id          = taggings#{nr}.tag_id"
      join << " AND #{sanitize_sql( ["tags#{nr}.type=?", options.delete(:type).to_s ] )}" if options[:type]
      join << " AND #{sanitize_sql( ["tags#{nr}.data_id=?", options.delete(:tag).to_s  ] )}" if options[:tag]
      join << " AND ( tags#{nr}.data_id='#{options.delete(:tags).join("' OR tags#{nr}.data_id='")}')"  if options[:tags]

      return { :joins => join.join( ' ' ), :conditions => cond.join( ' AND ' ), :order => 'items.time DESC'}
   end

   # URL to get thumbshot
   def thumbshot( url )
      "http://www.thumbshots.de/cgi-bin/show.cgi?url=#{url}/.png"  #add /.png to get rif of error ms
   end

   #---------------------------------------------------------------------------------------------------------------------
   # Extracts tags, people and locations
   def extract_all
      extract_links_and_images
      extract_meta_people_locations
   end

   # Extract links and images
   def extract_links_and_images( from = nil )
      from = text unless from
      d = from.gsub( / www\./, ' http://www.').gsub( /'"/, '')
      URI::extract( d, 'http' ) do |url|
         type = ( url =~ /\.(png|jpg|gif)/ ) ? :image : :link
         tag( type => url )
      end
   end

   # Extracts everthing fomr http://tagthe.net
   def tag_the_net( from_url = nil  )
      from_url = ( from_url ) ? "url=#{from_url}" : "text=#{CGI::escape(text.gsub( /<[^>]*>/, '' ))}"
      doc = Hpricot.XML( open( "http://tagthe.net/api/?#{from_url}" ) )
      (doc/"dim[@type='topic']/item").each    { |item| tag( :unknown => item.inner_html ) } # return all unkown tags
      (doc/"dim[@type='person']/item").each   { |item| tag( :person => item.inner_html ) } # return all people
      (doc/"dim[@type='location']/item").each { |item| tag( :location => item.inner_html ) } # return all locations
      (doc/"dim[@type='language']/item").each { |item| tag( :language => item.inner_html ) } # return all languages
      (doc/"dim[@type='author']/item").each   { |item| tag( :author => item.inner_html ) } # return all people
      #(doc/"dim[@type='title']/item").each # return all people
   end
   alias extract_meta_people_locations tag_the_net ##TODO it isn't called meta anymore

   # A simple datastructure to store title, url and text for an item
   class SimpleItem
      attr_accessor :title
      attr_accessor :url
      attr_accessor :text

      def initialize( data = {} )
         data.each do |key, value|
            send( "#{key.to_s}=", value)
         end
      end
   end
end

######################################################################################################
# Represents an image from Flickr - http://www.flickr.com
#--
# TODO is url correct?????
class FlickrItem < Item

   def raw_data=(d)
      return self.data = d if self.data_id
      self.data_id = [d.id, d.secret, d.owner_id].join(':')
      self.time = Time.now
   end

   def more_data=( d )
      self.time = d.dates[:taken] || d.dates[:posted]
      d.tags.each do |tag|
         tag( :vague => tag.clean )
      end
      # add notes, comments, date_posted
      self.data = SimpleItem.new( :url => d.url, :title => d.title, :text => d.description )
      tag( :image => data.url )
      tag( :link => url )
      self.complete = true
   end

   def thumbnail
      data.url.sub( /\.jpg/, '_s.jpg')
   end

   def info
      super +  "Comments:"  ##TODO: more info here!!
   end

   def url
      "http://www.flickr.com/photos/#{owner}/#{imgid}"  #TODO add user param here
   end

   def imgid
      @imgid, @secret, @owner = data_id.split(/:/) unless @imgid
      @imgid
   end

   def secret
      imgid unless @secret
      @secret
   end

   def owner
      imgid unless @owner
      @owner
   end

   def html
      "<img src='#{data.url.sub( /\.jpg/, '_m.jpg')}'>"
   end
end

######################################################################################################
# Represents a video from YouTube - http://www.youtube.com
class YoutubeItem < Item
   def raw_data=(d)
      self.data_id = d.id
      self.time = d.upload_time || Time.now
      tag( { :vague => d.tags }, ' ' )
      self.data = d
      tag( :video => url )
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

   # Return the html code for embedding the video
   def html(width = 425, height = 350)
      data.embed_html(width, height )
   end
end

######################################################################################################
# Represents a music Last.fm - http://www.last.fm
class LastfmItem < Item
   delegate :artist, :to => :data
   delegate :album,  :to => :data

   def raw_data=(d)
      self.data_id = d.url  ##TODO: is id available???
      self.time = d.date
      self.data = d
      tag( :link => url)
      tag( :artist => artist)
      self.complete = !album.nil?
   end

   def text
      [data.artist, data.album.title].join("\n")
   end

   def info
      "Date: #{time.strftime("%Y-%m-%d")}\nTitle: #{title}\nArtist: #{artist}\nAlbum: #{album.title}\nPlayed: #{time.to_s}"
   end

   def thumbnail
      return thumbshot( url ) if album.nil? or album.coverart.nil? or album.coverart.empty?
      data.album.coverart['small']
   end

   # Set the album
   def album=(album)
      return if album.nil?
      data.album = album
      self.complete = true
   end
end

######################################################################################################
# Represents a bookmark from Del.icious - http://del.icio.us
class DeliciousItem < Item
   def raw_data=(d)
      self.data_id = d.hash
      self.time = d.time
      tag( { :vague => d.tag }, ' ' )
      self.data = d
      tag( :bookmark => url)
      self.complete = true
   end

   def thumbnail
      thumbshot( url)
   end

   def rss=(r)
      self.time = Time.parse( (r/"dc:date").inner_html )
      r_url   = (r/"link").inner_html
      r_title = (r/"title").inner_html
      r_text  = (r/"description").inner_html
      self.data = SimpleItem.new( :url => r_url, :title => r_title,  :text => r_text )
      self.data_id = url
      tags = (r/"dc:subject").inner_html
      tag( { :vague => tags }, ' ' )
      tag( :link => url)
      self.complete = true
   end

   def json=(j)
      self.time = Time.now #fix this!!
      self.data = SimpleItem.new( :url => j['u'], :title => j['d'],  :text => j['n'] )
      self.data_id = url
      tag( :link => url)
      j['t'].each do |tag|
         tag( :vague => tag )
      end
      self.complete = true
   end
end

######################################################################################################
# Represents a posting from a blog
class BlogItem < Item
   def raw_data=(d)
      self.data_id = d['postid']
      time = d['dateCreated'].to_time
      return if time > Time.now #get rid of future posts
      return unless time.to_i > 0  #get rid of drafts
      self.time = time
      self.data = SimpleItem.new( :url => d['permaLink'], :title => d['title'],  :text => d['description'] )
      extract_all
      tag( :blog => url)
      self.complete = true
   end
end

######################################################################################################
# Represents a search result by yahoo
class YahoosearchItem < Item
   def raw_data=(d)
      self.data_id = d['Url']
      self.time = Time.at( d['ModificationDate'].to_i )
      self.complete = true
      self.data = d
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
# Represents a posting from Twitter - http://www.twitter.com
class TwitterItem < Item
   def raw_data=(d)
      self.data_id = d.id
      self.time = d.created_at
      self.data = d
      self.complete = true
   end

   def url
      "http://www.twitter.com/#{data.user.screen_name}/statuses/#{data.id}"
   end

   def title
      "#{data.user.name} says"
   end

   def thumbnail
      return thumbshot( @links.first ) if @links.first
      thumbshot( url )
   end

   def info
      super
   end
end

######################################################################################################
# Represents a location by Plazes  http://www.plazes.com
class PlazesItem < Item
   delegate :plaze,    :to => :data
   delegate :street,   :to => :plaze
   delegate :zip,      :to => :plaze
   delegate :city,     :to => :plaze
   delegate :country,  :to => :plaze
   delegate :latitude, :to => :plaze
   delegate :longitude,:to => :plaze
   delegate :blog_url, :to => :plaze

   def raw_data=(d)
      return unless d.plaze.name
      self.time = d.start.to_time
      self.data_id = "#{d.plaze.key}#{self.time.to_i}"
      self.data = d
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
