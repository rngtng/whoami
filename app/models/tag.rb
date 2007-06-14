####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class Tag < ActiveRecord::Base
   TAG_DELIMITER = " " # how to separate tags in strings

   serialize  :data

   # if speed becomes an issue, you could remove these validations and rescue the AR index errors instead
   validates_presence_of :name
   #validates_uniqueness_of :name #, :case_sensitive => false
   validates_presence_of   :data_id
   validates_uniqueness_of :data_id

   #validates_format_of :name, :with => /^[a-zA-Z0-9\_\-]+$/,
   #:message => "can not contain special characters"

   #acts_as_tree

   cattr_accessor :max_count
   self.max_count = 0

   cattr_accessor :default_type
   self.default_type = :vague

   def self.split_and_get( name, split_by = nil )
      return Tag.get( name ) unless split_by #fallback if nothing to split
      tags = []
      type = Tag.default_type
      type, name = name.shift if name.is_a? Hash
      name.split( split_by ).each do |item|
         tags << Tag.get( type => item)
      end
      return tags
   end

   def self.get( name )
      #puts "++++++++++++++++++++++++++++"
      type = Tag.default_type
      type, name = name.shift if name.is_a? Hash
      type, name = process_tag( type, name )   #fliter special tag/keys--
      #puts "+++ #{name.to_s}"
      tag = Tag.find_by_data_id( name.to_s ) #TODO find similar! prepare before!?
      tag = Tag.find_by_name( name.to_s ) if !tag #TODO find similar! prepare before!?
      #puts "+++ found  #{tag.id} #{tag.data_id} #{tag.name}" if tag
      tag = Tag.factory( type, :name => name ) unless tag
      tag = tag.change_type!( type ) unless tag.is_type?( type )  ##force change of typ
      tag.save if !tag.id or tag.new_record? or !tag.is_type?( type )
      #puts "+++  #{tag.id} #{tag.data_id} #{tag.name}"
      return tag
   end

   def self.change_type( type, old)
      new_tag = Tag.factory( type, old.attributes )
      new_tag[:id] = old.id if old.id
      new_tag.new_record = old.new_record?
      new_tag
   end

   def self.factory( type, params = {} )
      class_name = type.to_s.capitalize
      raise unless defined? class_name.constantize
      params[:data_id] = params[:name].to_s if params[:name] and !params[:data_id]
      class_name.constantize.new( params )
   end

   def self.types
      @types ||= subclasses.collect do |type|
         type.to_s.downcase.pluralize.intern
      end
      @types.map ##return a copy!
   end

   def self.has_type?(typ)
      Tag.types.include?( typ.to_s.downcase.pluralize.to_sym )
   end

   def self.concepts
      return [self.to_sym] if  self.to_sym == Tag.default_type
      [ self.to_sym ] + superclass.concepts
   end

   def self.to_sym
      to_s.downcase.intern
   end

   #############################################################################
   def after_find
      self.max_count = count if count && self.max_count < count
   end

   #############################################################################
   def change_type!(typ)
      return self if is_concept_of?( typ ) #no changing if is's a (sub)concept!
      puts "##try changing id#{id}/#{type} -#{name}- to #{typ.to_s}:"
      return self unless Tag.has_type?( typ )  #check if allowed type
      puts "  --> changeing!!"
      new_tag = Tag.change_type( typ, self )
   end

   def name=(name)
      super( name.strip.gsub( '"', '').gsub("'", '' ).squeeze(" ") )
   end

   def type
      return 'tag' unless self[:type]
      self[:type].downcase
   end

   def new_record=(n_r)
      @new_record= n_r
   end

   def ==(object)
      super || (object.is_a?(Tag) && name == object.name)
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

   def is_place?

   end

   def is_person?
   end

   private
   def self.process_tag( key, tag )
      #return nil if tag =~/geo:l/ 	  #TODO won't work
      return [ :location, "http://beta.plazes.com/plaze/#{$1}" ] if tag =~ /plaze([a-z0-9]{32})/
      [key, tag]
   end
end

#############################################################################
class Vague < Tag
   def name=(name)
      super(name.downcase)
   end
end

class Nonsense < Tag
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
      cnt = (content%"totalresultscount").inner_html.to_i
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
   def name=(n)
      self.name = name
   end

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

