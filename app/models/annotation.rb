####################
#
# $LastChangedDate:2007-08-07 15:37:28 +0200 (Tue, 07 Aug 2007) $
# $Rev:94 $
# by $Author:bielohla $

# Class representing a annotation
class Annotation < ActiveRecord::Base
   TAG_DELIMITER = " " # how to separate annotations in strings

   serialize  :data

   # if speed becomes an issue, you could remove these validations and rescue the AR index errors instead
   validates_presence_of :name
   #validates_uniqueness_of :name #, :case_sensitive => false
   validates_presence_of   :data_id
   validates_uniqueness_of :data_id

   #validates_format_of :name, :with => /^[a-zA-Z0-9\_\-]+$/,
   #:message => "can not contain special characters"

   # The maximum of annotations found in a query
   #--
   # FIXME: am I counting right?
   cattr_accessor :max_count
   self.max_count = 0

   # The default annotation type if not specified
   cattr_accessor :default_type

   # Splits name by split_by and created & returns the annotations
   def self.split_and_get( names, split_by = nil )
      return Annotation.get( names ) unless split_by #fallback if nothing to split
      annotations = []
      type = :topic
      type, names = names.shift if names.is_a? Hash
      names.split( split_by ).each do |resource|
         annotations << Annotation.get( type => resource)
      end
      return annotations
   end

   # Returns the annotation with name in case it exists. If not the annotation is created and
   # returned.
   def self.get( name )
      type = :topic
      type, name = name.shift if name.is_a? Hash
      type, name = Annotation.process_annotation( type, name )   #fliter special annotation/keys--
      annotation = Annotation.find_by_data_id( name.to_s ) #TODO find similar! prepare before!?
      annotation = Annotation.find_by_name( name.to_s ) if !annotation #TODO find similar! prepare before!?
      annotation = Annotation.factory( type, :name => name ) unless annotation
      annotation.save! if annotation.new_record?
      annotation = Annotation.change_type!( type, annotation ) if annotation.has_concept?( type )
      return annotation
   end

   # Changes annotation type. As this changes the object type as well, the returned annotation has to be assigned to
   # the variable:
   #  annotation = Annotation.change_type( :location, annotation )
   def self.change_type!( type, old)
      puts "##changing id#{old.id}/#{old.type} -#{old.name}- to #{type.to_s}"
      new_annotation = Annotation.factory( type, old.attributes )
      new_annotation[:id] = old.id
      old.destroy
      new_annotation.save!
      new_annotation
   end

   # Created a annotation of given type
   def self.factory( type, params = {} )
      class_name = type.to_s.capitalize
      raise unless defined? class_name.constantize
      params[:data_id] = params[:name].to_s if params[:name] and !params[:data_id]
      class_name.constantize.new( params )
   end

   # List of available annotation types
   def self.types
      @types ||= subclasses.collect do |type|
         type.to_s.downcase.pluralize.intern
      end
      @types.map ##return a copy!
   end

   # Checks if annotation type is valid
   #def self.has_type?(typ)
   #   Annotation.types.include?( typ.to_s.downcase.pluralize.to_sym )
   #end

   # List of concepts
   def self.concepts
      subclasses_of( self ).collect( &:to_sym )
   end

   # Get annotation class name as smybol
   def self.to_sym
      to_s.downcase.intern
   end

   #############################################################################
   def after_find
      self.max_count = count if count && self.max_count < count
   end

   #############################################################################
   # Sets the name of the annotation
   def strip_name(name)
      name.strip.gsub( '"', '').gsub("'", '' ).squeeze(" ")
   end

   def name=(name)
      super( strip_name( name ) )
   end

   # Returns the annotation type
   def type
      return 'annotation' unless self[:type]
      self[:type].downcase
   end

   # Set the new_record status
   def new_record=(n_r)
      @new_record= n_r
   end

   # Compares two annotation if equal
   def ==(object)
      super || (object.is_a?(Annotation) && name == object.name)
   end

   def to_s
      name
   end

   def count
      read_attribute(:count).to_i
   end

   #########################
   def is_type?( typ )
      self.type == typ.to_s.downcase
   end

   def has_concept?( typ )
      self.class.concepts.include?( typ )
   end

   private
   def self.process_annotation( key, annotation )
      #return [ :lat,  "#{$1}" ] if annotation =~/geo:lat=([0-9.])/
      #return [ :long, "#{$1}" ] if annotation =~/geo:long=([0-9.])/
      raise Exception.new  if annotation =~/geo:lat=([0-9.])/
      raise Exception.new  if annotation =~/geo:long=([0-9.])/
      return [ :url, "http://beta.plazes.com/plaze/#{$1}" ] if annotation =~ /plaze([a-z0-9]{32})/
      [key, annotation]
   end
end

#############################################################################
#class Unknown < Annotation
#   def name=(name)
#      super(name.downcase)
#   end
#end

class Topic < Annotation
end

class Tag < Topic
end

#############################################################################
class Person < Tag
   #TODO only allow [^a-zA-z. ]
end

class Artist < Person
end

class Author < Person
end

#############################################################################
class Location < Tag

   def self.new( params = {} )
      check_and_get_if_geo( super( params ) )
   end

   def self.check_and_get_if_geo( new )
      return new if new.is_a? Geo #is already geo
      url = "http://ws.geonames.org/search?q=#{URI.escape(new.name)}&maxRows=1&style=FULL"
      content = Hpricot.XML( open( url ) )
      cnt = (content%"totalResultsCount")
      puts "## results for -#{new.name}-: #{cnt.inner_html.to_i}"
      return new if !cnt or cnt.inner_html.to_i < 1
      new.data = content
      #new.synonym = (content%"alternateNames").inner_html
      return Annotation.factory( :geo, new.attributes )
   end

   def name=(name)
      super(name.downcase)
   end
end

class Geo < Location
   #http://local.yahooapis.com/MapsService/V1/geocode?appid=YahooDemo&street=701+First+Street&city=Sunnyvale&state=CA <- local search

   def lng
      (data%"lng").inner_html
   end

   def lat
      (data%"lat").inner_html
   end

   def ll
      [lat,lng]
   end

   def name=(name)
      return super(name) if name.is_a? String # =~ /lat:([^;]+);lng:(.+)$/
      self.data = get_place_name( name[:lat], name[:lng])
      super( (data%'name').inner_html )
   end

   private
   def get_place_name(lat, lng )
      url = "http://ws.geonames.org/findNearbyPlaceName?lat=#{lat}&lng=#{lng}&maxRows=1&style=FULL"
      return Hpricot.XML( open( url ) )
   end
end

#############################################################################
class Language < Tag
end

#############################################################################
class Url < Tag
   def thumbnail
      self.name
   end
end

class Image < Url
   def thumbnail
      self.name
   end
end

class Blog < Url
end

class Video < Url
end

#class Bookmark < Url
#end

