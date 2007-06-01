class Tag < ActiveRecord::Base
  TAG_DELIMITER = " " # how to separate tags in strings

  # if speed becomes an issue, you could remove these validations and rescue the AR index errors instead
  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false
  #validates_format_of :name, :with => /^[a-zA-Z0-9\_\-]+$/, 
  #:message => "can not contain special characters"
    
  #acts_as_tree
  
  cattr_accessor :max_count
  self.max_count = 0
  
  def self.types
	    @types ||= subclasses.collect do |type|
	        type.to_s.downcase.pluralize.intern
	    end	
	    @types.map ##return a copy!
  end
	
  def self.get( to_tag, split_by = nil )
     split_by = to_tag.delete(:split) if to_tag[:split]	  
     return self.split_and_get( to_tag, split_by ) if split_by	  
     key = :note
     key, to_tag = to_tag.shift if to_tag.is_a? Hash
     key, to_tag = process_tag( key, to_tag )   #fliter special tag/keys--
     tag = Tag.find_by_name( to_tag )
     tag = key.to_s.classify.constantize.create( :name => to_tag ) unless tag
     if tag.type != key.to_s  ##force change of type
	     puts "####################"
	     puts "changing tagtype #{tag.name} from #{tag.type} to #{key.to_s}"
	     tag = tag.change_type( key )
     end     
     return tag
  end
  
  def self.split_and_get( to_tag, split_by )
     tags = []
     key = :note	  
     key, to_tag = to_tag.shift if to_tag.is_a? Hash
     to_tag.split( split_by ).each do |item|
         tags << self.get( key => item)
     end
     return tags
  end   
  
  #############################################################################
  def before_create 
    self.name = name.strip.squeeze(" ") # if you allow editable tag names, you might want before_save instead
  end
  
  def after_find
	self.max_count = count if count && self.max_count < count
  end
  
  #############################################################################
  def type
     @type ||= self[:type].downcase
  end

  
  def change_type( typ )
	  typ = typ.to_s.downcase
          return self if type == typ ##no need to change type
          return self unless Tag.types.include?( typ.pluralize.to_sym ) 	  #check if allowed type
          self[:type] = typ.classify
	  save
	  Tag.find id
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
class Note < Tag
  def before_create 
    self.name = name.downcase.strip.squeeze(" ") # if you allow editable tag names, you might want before_save instead
  end
end

#############################################################################
class Person < Tag
  def before_create 
    self.name = name.downcase.strip.squeeze(" ") # if you allow editable tag names, you might want before_save instead
  end
  #TODO only allow [^a-zA-z. ]
end

#############################################################################
class Location < Tag
   def before_create 
     self.name = name.downcase.strip.squeeze(" ") # if you allow editable tag names, you might want before_save instead
   end
   #http://ws.geonames.org/postalCodeSearch?placename=kaiserslaute&maxRows=10
   #http://local.yahooapis.com/MapsService/V1/geocode?appid=YahooDemo&street=701+First+Street&city=Sunnyvale&state=CA
end	

#############################################################################
class Image < Tag
	
end

#############################################################################
class Language < Tag
	
end

#############################################################################
class Nothing < Tag
	
end

#############################################################################
class Link < Tag
	#is_blog?
	#thumbnail
end


#############################################################################
class Geotag < Tag
  def get_place_name( lat, lng )
    #"http://ws.geonames.org/findNearbyPlaceName?lat=#{lat}&lng=#{lng}" 
  end	
	
end

