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
   self.default_type = :unknown

   # Splits name by split_by and created & returns the annotations
   def self.split_and_get( names, split_by = nil )
      return Annotation.get( names ) unless split_by #fallback if nothing to split
      annotations = []
      type = Annotation.default_type
      type, names = names.shift if names.is_a? Hash
      names.split( split_by ).each do |resource|
         annotations << Annotation.get( type => resource)
      end
      return annotations
   end

   # Returns the annotation with name in case it exists. If not the annotation is created and
   # returned.
   def self.get( name )
      type = Annotation.default_type
      type, name = name.shift if name.is_a? Hash
      type, name = process_annotation( type, name )   #fliter special annotation/keys--
      annotation = Annotation.find_by_data_id( name.to_s ) #TODO find similar! prepare before!?
      annotation = Annotation.find_by_name( name.to_s ) if !annotation #TODO find similar! prepare before!?
      annotation = Annotation.factory( type, :name => name ) unless annotation
      annotation = annotation.change_type!( type ) unless annotation.is_type?( type )  ##force change of typ
      annotation.save if !annotation.id or annotation.new_record? or !annotation.is_type?( type )
      return annotation
   end

   # Changes annotation type. As this changes the object type as well, the returned annotation has to be assigned to
   # the variable:
   #  annotation = Annotation.change_type( :location, annotation )
   def self.change_type( type, old)
      new_annotation = Annotation.factory( type, old.attributes )
      new_annotation[:id] = old.id if old.id
      new_annotation.new_record = old.new_record?
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
   def self.has_type?(typ)
      Annotation.types.include?( typ.to_s.downcase.pluralize.to_sym )
   end

   # List of concepts
   def self.concepts
      return [self.to_sym] if  self.to_sym == Annotation.default_type
      [ self.to_sym ] + superclass.concepts
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
   def name=(name)
      super( name.strip.gsub( '"', '').gsub("'", '' ).squeeze(" ") )
   end

   # Changes the annotation type
   def change_type!(typ)
      return self if is_concept_of?( typ ) #no changing if is's a (sub)concept!
      puts "##try changing id#{id}/#{type} -#{name}- to #{typ.to_s}:"
      return self unless Annotation.has_type?( typ )  #check if allowed type
      puts "  --> changeing!!"
      new_annotation = Annotation.change_type( typ, self )
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

   def is_concept_of?( typ )
      self.class.concepts.include?( typ )
   end

   #def is_place?
   #end

   #def is_person?
   #end

   private
   def self.process_annotation( key, annotation )
      #return nil if annotation =~/geo:l/ 	  #TODO won't work
      return [ :location, "http://beta.plazes.com/plaze/#{$1}" ] if annotation =~ /plaze([a-z0-9]{32})/
      [key, annotation]
   end
end

#############################################################################
class Unknown < Annotation
   def name=(name)
      super(name.downcase)
   end
end

class Vague < Unknown
end

class Nonsense < Annotation
   def is_concept_of?(typ)
      true #is concept of everything
   end
end

#############################################################################
class Person < Vague

   def name=(name)
      super(name.downcase)
   end
   #TODO only allow [^a-zA-z. ]
end

class Artist < Person
end

class Author < Person
end

#############################################################################
class Location < Vague

   def self.new( params = {} )
      check_and_get_if_geo( super( params ) )
   end

   def self.check_and_get_if_geo( new )
      return new if new.is_a? Geo #is already geo
      url = "http://ws.geonames.org/search?q=#{URI.escape(new.name)}&maxRows=1&style=FULL"
      content = Hpricot.XML( open( url ) )
      cnt = (content%"totalresultscount")
      return new unless cnt
      cnt.inner_html.to_i #TODO
      puts "## results for -#{new.name}-: #{cnt}"
      return new unless  cnt > 0 # (1..100) === cnt
      new.data = content
      new.synonym = (content%"alternatenames").inner_html
      return new.change_type!( :geo )
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
class Image < Vague
   def thumbnail
      self.name
   end
end

#############################################################################
class Language < Vague
end


#############################################################################
class Link < Vague
   def thumbnail
      self.name
   end
end

class Blog < Link
end

class Video < Link
end

class Bookmark < Link
end
