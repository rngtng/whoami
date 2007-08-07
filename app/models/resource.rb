####################
#
# $LastChangedDate:2007-08-07 15:37:28 +0200 (Tue, 07 Aug 2007) $
# $Rev:94 $
# by $Author:bielohla $

# Class representing an resource
#-- require 'annotation'
class Resource < ActiveRecord::Base
   belongs_to :account  #, :counter_cache => true

   delegate :user,                :to => :account
   delegate :url, :title, :text,  :to => :data

   has_many_polymorphs :annotations, :through => :annotatings, :from =>  Annotation.types

   serialize  :data

   validates_associated    :account
   validates_presence_of   :time
   validates_presence_of   :data_id
   validates_uniqueness_of :data_id, :scope => 'account_id' #we need that to check if resource is allready in DB

   after_save :save_annotations

   #Returns Resources subclass of type type
   def self.factory( type, *params )
      class_name = type.capitalize + "Resource"
      raise unless defined? class_name.constantize
      class_name.constantize.new( *params )
   end

   #Annotations of the resources
   def self.annotations( options = {} )
      opt = prepage_query( options )
      opt[:from]   = 'resources'
      opt[:select] = 'annotations.*, COUNT(annotations.id) count'
      opt[:group]  = 'annotations.id'
      Annotation.find( :all, opt )
   end

   #Find resources annotated with the given options. This can be:
   #  * :account_id => ID - only resources from a specific account
   #  * :from => time - resources not older than time
   #  * :to => time - resources not younger then time
   #  * :time => time - resources not older than time
   #  * :period => timespan - resources not younger then time + period
   #  * :annotation => name - resources which match this annotation
   #  * :annotations => array of names - resources which match a least one of the annotations
   #  * :TAGTYPE => name
   def self.find_annotated_with( options = {})
      opt = prepage_query( options, 'ftw' )  #set uniqe identifier -ftw- to be able to extend query...
      scope( :find )[:select] = 'resources.*, COUNT(resources.id) as count'
      opt[:group]  = 'resources.id HAVING count > 0'
      #opt[:having]  = 'count > 0'
      #puts '##############################'
      #pp opt
      #pp scope( :find )
      result = Resource.find( :all, opt )
      return result unless @annotation_types
      result.instance_variable_set( :@options, opt )
      #add some helpfull methods to array
      @annotation_types.each do |annotation|
         result.instance_eval <<-end_eval
         def #{annotation.to_s}
            Resource.#{annotation.to_s}( @options.merge( {} ) )
         end
         end_eval
      end
      return result
   end

   #Returns an array of resources as iCal Format
   def self.to_calendar( resources )
      cal = Icalendar::Calendar.new
      cal.custom_property("METHOD","PUBLISH")
      resources.each do |i|
         cal.add_event( i.to_event )
      end
      cal
   end

   # Find oldest resources
   def self.min_time
      scope(:find)[:select] = 'MIN(resources.time) AS time'
      Resource.find( :first ).time
   end

   # Find youngest (lastest) resources
   def self.max_time
      scope(:find)[:select] = 'MAX(resources.time) AS time'
      Resource.find( :first ).time
   end

   # List of annotation types
   def self.annotation_types
      @annotation_types
   end

   # Add a dynamic methods to class for getting annotations for all resources
   def self.annotation_types=( annotation_types )
      @annotation_types = annotation_types
      @annotation_types.each do |annotation|
         class_eval <<-end_eval
         def self.#{annotation.to_s}( options = {} )
            options[:type] = "#{annotation.to_s.classify}"
            annotations( options )
         end
         end_eval
      end
   end
   self.annotation_types = Annotation.types

   # Condition for a valid resource
   def self.valid_condition( valid = true)
      [ 'resources.complete = ?', valid  ]
   end

   ###############################################################################################
   # Complete info of an resource
   def info
      info = ["Id:    #{id}"]
      info << "Date:  #{time.strftime('%Y-%m-%d')}"
      info << "Title: #{title}"
      info << "Text:  #{text}"
      self.class.superclass.annotation_types.each do |annotation|
         annotation = annotation.to_s
         annotations = send( annotation ).join(', ')
         info << "#{annotation.capitalize}: #{annotations}" unless annotations.empty?
      end
      info << "----------\n"
      info.join("\n")
   end

   # Returns thumbnail. If available the first annotated image is returned, if not thumbshot of the first
   # link, if this fails to, the thumbshot of url is taken
   def thumbnail
      return images.first.thumbnail unless images.empty?
      return thumbshot( links.first.thumbnail ) unless links.empty?
      thumbshot( url )
   end

   # Returns resource as iCal event
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

   # Type of the resource
   def type
      @type ||= self.class.to_s.downcase.sub( /resource/, '' )
   end

   # Html code to diplay instead fo default code
   def html( width = 50, height = 50 )
      false
   end

   # Get the account color for the resource.
   def color #much faster than delegte to account.color!
      "#{type}_account".classify.constantize.color
   end

   ###############################################################################################
   # Annotations resource with annotation. If split_by is provided, annotation is splited in server annotations
   # annotation can be a Sting, a Hash where :Annotationtype => AnnotationName or a Annotation
   def annotation( annotation, split_by = nil )
      @cached_annotations ||= []
      annotation = Annotation.split_and_get( annotation, split_by )  unless annotation.is_a? Annotation
      @cached_annotations  <<  annotation
   end

   # Save annotations
   def save_annotations
      annotations << @cached_annotations if @cached_annotations
   end

   # Set resource data taken from a feed entry
   def feed=(f)
      self.data_id = f.id || f.urls.first
      self.time = f.date_published || Time.now
      self.data = SimpleResource.new( :url => f.url, :title => f.title,  :text => f.description )
      annotation( :link => url ) #TDODO specify better type here?
      extract_all
      self.complete = true
   end

   # Get related resources. This can be via:
   # * annotations:
   # * time:
   def related_resources( options = {} )
      options[:time] = time if options[:period] && !options[:time]
      options[:conditions] = ["resources.id !=? AND resources.complete=1", id ]
      options[:having] = "cnt > 2"
      account.user.resources.find_annotated_with( options )
   end

   ###############################################################################################
   private
   # Prepares the query for finding annotations and annotated resources
   #--
   # TODO :location => 'esa' should work to
   def self.prepage_query( options = {}, nr = '')	# eg. :annotation => 'esa' :type - :account_id - :period, :time
      scope = scope(:find)
      cond = ["1"]
      cond << sanitize_sql(scope.delete(:conditions)) if scope && scope[:conditions]
      cond << sanitize_sql(options.delete(:conditions)) if options[:conditions]
      cond << sanitize_sql( ['resources.account_id=?', options.delete(:account_id) ] ) if options[:account_id]

      if options[:from] and options[:to]
         options[:time] = options.delete(:from )
         options[:period] = options.delete(:to ).to_i - options[:time].to_i
      end
      if options[:time]
         period = ( options[:period] ) ?  options.delete(:period) : 2.days
         past   = ( period <  0 ) ? period : 0
         future = ( period >= 0 ) ? period : 0
         time   = Time.at( options.delete(:time).to_i )
         cond << sanitize_sql( [ "resources.time >= ? AND resources.time <= ?", time+past, time+future ] )
      end

      join = []
      join << scope.delete(:joins) if scope && scope[:joins]
      join << options.delete(:joins) if options[:joins]
      join << "INNER JOIN annotatings AS annotatings#{nr} ON annotatings#{nr}.resource_id = resources.id"
      join << "INNER JOIN annotations     AS annotations#{nr}     ON annotations#{nr}.id          = annotatings#{nr}.annotation_id"
      join << " AND #{sanitize_sql( ["annotations#{nr}.type=?", options.delete(:type).to_s ] )}" if options[:type]
      join << " AND #{sanitize_sql( ["annotations#{nr}.data_id=?", options.delete(:annotation).to_s  ] )}" if options[:annotation]
      join << " AND ( annotations#{nr}.data_id='#{options.delete(:annotations).join("' OR annotations#{nr}.data_id='")}')"  if options[:annotations]

      return { :joins => join.join( ' ' ), :conditions => cond.join( ' AND ' ), :order => 'resources.time DESC'}
   end

   # URL to get thumbshot
   def thumbshot( url )
      "http://www.thumbshots.de/cgi-bin/show.cgi?url=#{url}/.png"  #add /.png to get rif of error ms
   end

   #---------------------------------------------------------------------------------------------------------------------
   # Extracts annotations, people and locations
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
         annotation( type => url )
      end
   end

   # Extracts everthing fomr http://annotationthe.net
   def annotation_the_net( from_url = nil  )
      from_url = ( from_url ) ? "url=#{from_url}" : "text=#{CGI::escape(text.gsub( /<[^>]*>/, '' ))}"
      doc = Hpricot.XML( open( "http://annotationthe.net/api/?#{from_url}" ) )
      (doc/"dim[@type='topic']/resource").each    { |resource| annotation( :unknown => resource.inner_html ) } # return all unkown annotations
      (doc/"dim[@type='person']/resource").each   { |resource| annotation( :person => resource.inner_html ) } # return all people
      (doc/"dim[@type='location']/resource").each { |resource| annotation( :location => resource.inner_html ) } # return all locations
      (doc/"dim[@type='language']/resource").each { |resource| annotation( :language => resource.inner_html ) } # return all languages
      (doc/"dim[@type='author']/resource").each   { |resource| annotation( :author => resource.inner_html ) } # return all people
      #(doc/"dim[@type='title']/resource").each # return all people
   end
   alias extract_meta_people_locations annotation_the_net ##TODO it isn't called meta anymore

   # A simple datastructure to store title, url and text for an resource
   class SimpleResource
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
class FlickrResource < Resource

   def raw_data=(d)
      return self.data = d if self.data_id
      self.data_id = [d.id, d.secret, d.owner_id].join(':')
      self.time = Time.now
   end

   def more_data=( d )
      self.time = d.dates[:taken] || d.dates[:posted]
      d.annotations.each do |annotation|
         annotation( :vague => annotation.clean )
      end
      # add notes, comments, date_posted
      self.data = SimpleResource.new( :url => d.url, :title => d.title, :text => d.description )
      annotation( :image => data.url )
      annotation( :link => url )
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
class YoutubeResource < Resource
   def raw_data=(d)
      self.data_id = d.id
      self.time = d.upload_time || Time.now
      annotation( { :vague => d.annotations }, ' ' )
      self.data = d
      annotation( :video => url )
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
class LastfmResource < Resource
   delegate :artist, :to => :data
   delegate :album,  :to => :data

   def raw_data=(d)
      self.data_id = d.url  ##TODO: is id available???
      self.time = d.date
      self.data = d
      annotation( :link => url)
      annotation( :artist => artist)
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
class DeliciousResource < Resource
   def raw_data=(d)
      self.data_id = d.hash
      self.time = d.time
      annotation( { :vague => d.annotation }, ' ' )
      self.data = d
      annotation( :bookmark => url)
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
      self.data = SimpleResource.new( :url => r_url, :title => r_title,  :text => r_text )
      self.data_id = url
      annotations = (r/"dc:subject").inner_html
      annotation( { :vague => annotations }, ' ' )
      annotation( :link => url)
      self.complete = true
   end

   def json=(j)
      self.time = Time.now #fix this!!
      self.data = SimpleResource.new( :url => j['u'], :title => j['d'],  :text => j['n'] )
      self.data_id = url
      annotation( :link => url)
      j['t'].each do |annotation|
         annotation( :vague => annotation )
      end
      self.complete = true
   end
end

######################################################################################################
# Represents a posting from a blog
class BlogResource < Resource
   def raw_data=(d)
      self.data_id = d['postid']
      time = d['dateCreated'].to_time
      return if time > Time.now #get rid of future posts
      return unless time.to_i > 0  #get rid of drafts
      self.time = time
      self.data = SimpleResource.new( :url => d['permaLink'], :title => d['title'],  :text => d['description'] )
      extract_all
      annotation( :blog => url)
      self.complete = true
   end
end

######################################################################################################
# Represents a search result by yahoo
class YahoosearchResource < Resource
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
class TwitterResource < Resource
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
class PlazesResource < Resource
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
#a.resources.each do | i | i.get_annotations; i.save; end
#def get_annotations
#   t = text.gsub( /&/, 'und' ).gsub( /[^a-zA-Z0-9 ] /, ' ')
#   annotations = [ 'b', 'i', 'strong', 'em' ]
#   resp = XmlSimple.xml_in( "<html>#{t}</html>", { 'ForceArray' => annotations })
#   r = title
#   annotations.each do | t |
#     r = [ r, resp[t] ].join( ' ') if resp[t]
#   end
#   Annotation.delimiter = ' '
#   self.annotation_list = r
#end

