####################
#
# $LastChangedDate:2007-08-07 15:37:28 +0200 (Tue, 07 Aug 2007) $
# $Rev:94 $
# by $Author:bielohla $

# Class representing an resource. Every specific resource implementation is inherited from Resource and extended for specific
# resource attributes and methods. The STI (Single Table Interhitance) Pattern is used for a clean structure
# A resource belongs to an account and can have many tags. Tag relations are build with has_many_polymorphes
class Resource < ActiveRecord::Base
   act_as_event_resource #plugin, adds to_event support

   belongs_to :account  # :counter_cache => true

   scope_out :incomplete, :conditions =>  [ 'complete=?', false ]
   scope_out :complete,   :conditions =>  [ 'complete=?', true ]

   #TODO scope_out :min,        :conditions =>  [ 'resources.complete=?', true ]
   #TODO scope_out :max,        :conditions =>  [ 'resources.complete=?', true ]

   delegate :user, :to => :account

   has_many_polymorphs :annotations, :through => :annotatings, :from =>  Annotation.types

   serialize  :data

   validates_associated    :account
   validates_presence_of   :time
   validates_presence_of   :data_id
   validates_uniqueness_of :data_id, :scope => 'account_id' #we need that to check if resource is allready in DB

   after_save :save_annotations

   #Returns Resources subclass of type type
   def self.factory( type, *params )
      class_name = type.to_s.capitalize + "Resource"
      raise unless defined? class_name.constantize
      class_name.constantize.new( *params )
   end

   #Annotations of the resources
   def self.annotations( options = {} )
      opt = prepage_query( options )
      opt[:from]   = 'resources'
      opt[:select] = 'annotations.*, COUNT(annotations.id) count'
      opt[:group]  = 'annotations.id'
      opt[:order]  = 'annotations.type, annotations.name'
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
      #TODO: opt[:having]  = 'count > 0'
      #TODO: puts '##############################'      #pp opt      #pp scope( :find )
      result = Resource.find( :all, opt )
      return result unless @annotation_types
      result.instance_variable_set( :@options, opt )
      #dynamic extension: add some helpfull methods to array
      def result.annotations
         Resource.annotations( @options.merge( {} ) )
      end
      return result
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

   # # Add a dynamic methods to class for getting annotations for all resources
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
      thb = read_attribute( 'thumbnail' )
      thb = get_thumbnail if thb.empty?
      return thb
   end

   def get_thumbnail( thb = "" )
      thb = images.first.thumbnail unless images.empty?
      thb = thumbshot( urls.first.thumbnail ) if thb.empty? and !urls.empty?
      thb = thumbshot( url ) if thb.empty?
      self.thumbnail = thb && save unless thb.empty?
      return thb
   end

   # Type of the resource
   def type
      @type ||= self.class.to_s.downcase.sub( /resource/, '' )
   end

   # Html code to diplay instead fo default code
   def html( width = 50, height = 50 )
      false
   end

   # Save the url and add annotation
   def url=( url, type = :url)
      super( url )
      self.thumbnail = thumbshot( url )
      annotate( type => url )
   end

   # Get the account color for the resource.
   def color #much faster than delegte to account.color!
      "#{type}_account".classify.constantize.color
   end

   ###############################################################################################
   # Annotations resource with annotation. If split_by is provided, annotation is splited in server annotations
   # annotation can be a Sting, a Hash where :Annotationtype => AnnotationName or a Annotation
   def annotate( annotation )
      @cached_annotations ||= []
      annotation = Annotation.get( annotation )  unless annotation.is_a? Annotation
      @cached_annotations  <<  annotation if annotation
   end

   # Save annotations
   def save_annotations
      annotations << @cached_annotations if @cached_annotations
   end

   # Set resource data taken from a feed entry
   def feed=(f)
      self.data_id = f.id || f.urls.first
      t = f.date_published.to_i || Time.now.to_i
      self.time  = Time.at( t )
      self.url   = f.url
      self.title = f.title
      self.text  = f.content
      f.categories.each do | category |
         annotate( :tag => category )
      end
      f.authors.each do | author |
         annotate( :author => author )
      end
      Extractor.get_all( self.text ) { |type, tag | annotate( type => tag ) }
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
      join << "INNER JOIN annotations AS annotations#{nr} ON annotations#{nr}.id          = annotatings#{nr}.annotation_id"
      join << " AND #{sanitize_sql( ["annotations#{nr}.type=?", options.delete(:type).to_s ] )}"           if options[:type]
      join << " AND #{sanitize_sql( ["annotations#{nr}.data_id=?", options.delete(:annotation).to_s  ] )}" if options[:annotation] and !options[:annotation].empty?
      join << " AND ( annotations#{nr}.data_id='#{options.delete(:annotations).join("' OR annotations#{nr}.data_id='")}')"  if options[:annotations]

      return { :joins => join.join( ' ' ), :conditions => cond.join( ' AND ' ), :order => 'resources.time DESC'}
   end

   # URL to get thumbshot
   def thumbshot( url )
      "http://www.thumbshots.de/cgi-bin/show.cgi?url=#{url}/.png"  #add /.png to get rif of error ms
   end

end

######################################################################################################
# Represents an image from Flickr - http://www.flickr.com
#--
class FlickrResource < Resource

   # set raw/basic data
   def raw_data=(d)
      return self.data = d if self.data_id
      self.data_id   = [d.id, d.secret, d.owner_id].join(':')
      self.time      = Time.now
      self.url       = "http://www.flickr.com/photos/#{owner}/#{imgid}"
      self.thumbnail = d.url.sub( /\.jpg/, '_s.jpg')
      annotate( :image => d.url.sub( /\.jpg/, '.jpg') )
      # self.data = d
      self.complete = false
   end

   # set detail data
   def detail_data=( d )
      self.time   = d.dates[:taken] || d.dates[:posted]
      self.title  = d.title
      self.text   = d.description
      d.tags.each { |tag| annotate( :tag =>  tag.clean ) }
      self.complete = true
   end
   #TODO: add notes, comments, date_posted

   #def info
   #   super +  "Comments:"  ##TODO: more info here!!
   #end

   #HTML code to display image
   def html
      "<img src='#{thumbnail.sub( /\_s.jpg/, '_m.jpg')}'>" #TODO user image_tag helper here??
   end

   # image ID
   def imgid
      @imgid, @secret, @owner = data_id.split(/:/) unless @imgid
      @imgid
   end

   # secret phrase of the image
   def secret
      imgid unless @secret
      @secret
   end

   # owner of the image
   def owner
      imgid unless @owner
      @owner
   end
end

######################################################################################################
# Represents a video from YouTube - http://www.youtube.com
class YoutubeResource < Resource

   # set raw/basic data
   def raw_data=(d)
      self.data_id   = d.id
      self.time      = d.upload_time || Time.now
      self.title     = d.title
      self.text      = d.description
      self.url       = d.url
      self.thumbnail = d.thumbnail_url
      self.data      = d
      annotate( :video => "http://www.youtube.com/v/#{d.id}" )
      d.tags.split(' ').each { |tag| annotate( :tag =>  tag ) }
      self.complete = true
   end

   # return all infos about this resource
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
   #delegate :artist, :to => :data
   #delegate :album,  :to => :data

   # set raw/basic data
   def raw_data=(d)
      self.data_id   = d.url  ##TODO: is id available???
      self.time      = d.date
      self.url       = d.url
      self.thumbnail = thumbshot( d.url )

      annotate( :artist => artist)
      self.complete  = !album.nil?
   end

   # return all infos about this resource
   def info
      "Date: #{time.strftime("%Y-%m-%d")}\nTitle: #{title}\nArtist: #{artist}\nAlbum: #{album.title}\nPlayed: #{time.to_s}"
   end

   # Set the album
   def album=(album)
      return if album.nil?
      self.data.album = album
      self.thumbnail = data.album.coverart['small']
      self.text = [data.artist, data.album.title].join("\n")
      self.complete = true
   end

   # set data from feed (in fallback cases)
   #TODO:   #def feed=(r)
   #   self.time = Time.parse( (r/"pubDate").inner_html )
   #   r_url   = (r/"guid").inner_html
   #   r_title = (r/"title").inner_html
   #   r_text  = (r/"description").inner_html
   #   self.data = SimpleResource.new( :url => r_url, :title => r_title,  :text => r_text )
   #   self.data_id = url
   #   #annotations = (r/"dc:subject").inner_html
   #   #annotate( { :tag => annotations }, ' ' )
   #   #annotate( :url => url)
   #   self.complete = true
   #end
end

######################################################################################################
# Represents a bookmark from Del.icious - http://del.icio.us
class DeliciousResource < Resource

   # set raw/basic data
   def raw_data=(d)
      self.data_id = d.hash
      self.time  = d.time
      self.title = d.title
      self.text  = d.text
      self.url   = d.url
      self.data = d
      d.tags.split(' ').each { |tag|  annotate( :tag =>  tag ) }
      self.complete = true
   end

   # set data from feed (in fallback cases)
   def feed=(r)
      self.data_id = (r/"link").inner_html
      self.time    = Time.parse( (r/"dc:date").inner_html )
      self.title   = (r/"title").inner_html
      self.text    = (r/"description").inner_html
      self.url     = (r/"link").inner_html
      (r/"dc:subject").inner_html.split(' ').each { |tag|  annotate( :tag =>  tag ) }
      self.complete = true
   end
end

######################################################################################################
# Represents a posting from a blog
class BlogResource < Resource

   # set raw/basic data
   def raw_data=(d)
      self.data_id = d['postid']
      self.time    = d['dateCreated'].to_time
      return nil if self.time > Time.now or self.time.to_i < 1 #get rid of future posts and drafts
      self.title = d['title']
      self.text  = d['description']
      self.url   = d['permaLink'], :blog
      Extractor.get_tags( self.text ) { |type, tag | annotate( type => tag ) }
      Extractor.get_urls_and_images( self.text ) { |type, tag | annotate( type => tag ) }
      self.complete = true
   end

   # set data from feed (in fallback cases)
   def feed=(f)
      self.data_id = f.id || f.urls.first
      t = f.date_published.to_i || Time.now.to_i
      self.time  = Time.at( t )
      self.url   = f.url, :blog
      self.title = f.title
      self.text  = f.content
      f.categories.each {  | category |  annotate( :tag => category ) }
      f.authors.each { | author |  annotate( :author => author ) }
      Extractor.get_tags( self.text ) { |type, tag | annotate( type => tag ) }
      Extractor.get_urls_and_images( self.text ) { |type, tag | annotate( type => tag ) }
      self.complete = true
   end
end

