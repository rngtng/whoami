class Tag < ActiveRecord::Base
  TAG_DELIMITER = " " # how to separate tags in strings

  # if speed becomes an issue, you could remove these validations 
  # and rescue the AR index errors instead
  validates_presence_of :name
  validates_uniqueness_of :name, :case_sensitive => false
  #validates_format_of :name, :with => /^[a-zA-Z0-9\_\-]+$/, 
  #:message => "can not contain special characters"
    
  #acts_as_tree
  
  cattr_accessor :max_count
  self.max_count = 0
  
  def self.get( to_tag, split_by = nil )
     split_by = to_tag.delete(:split) if to_tag[:split]	  
     return self.split_and_get( to_tag, split_by ) if split_by	  
     key = :note
     key, to_tag = to_tag.shift if to_tag.is_a? Hash
     #key, tag = process_tag( key, to_tag )
     tag = Tag.find_by_name( to_tag )
     tag = key.to_s.classify.constantize.create( :name => to_tag ) unless tag
     return tag
  end
  
  def self.split_and_get( to_tag, split_by )
     tags = []
     key = :note	  
     key, to_tag = to_tag.shift if to_tag.is_a? Hash
     to_tag.downcase.split( split_by ).each do |item|
         tags << self.get( key => item)
     end
     return tags
  end   
  
  def self.find_popular()
    find(:all, :select => 'tags.*, count(*) as count', 
      :joins => "JOIN taggings ON taggings.tag_id = tags.id",
      :conditions => args[:conditions],
      :group => "taggings.tag_id" ) #      :order => "popularity DESC" 
  end
  
  #def self.to_s
  #	tags.map(&:to_s).join( ', ')
  #end
     
  #############################################################################
  def before_create 
    # if you allow editable tag names, you might want before_save instead 
    self.name = name.downcase.strip.squeeze(" ")
  end
  
  def after_find
	self.max_count = count if self.max_count < count
  end
  
  #############################################################################
  def ==(object)
    super || (object.is_a?(Tag) && name == object.name)
  end
  
  #def to_s
  #  name
  #end
  
  def count
    read_attribute(:count).to_i
  end
  
  def is_place?
   
  end	 
  
  def get_place_name( lat, lng )
   #"http://ws.geonames.org/findNearbyPlaceName?lat=#{lat}&lng=#{lng}" 
  end	
  
  def is_person?
  end	
  
  #private
  def self.process_tag( key, tag )
      return nil if tag =~/geo:l/ 	  
      return [ :location, "http://beta.plazes.com/plaze/#{$1}" ] if tag =~ /plaze([a-z0-9]{32})/ 	  
      [key, tag.downcase]
  end
end

#############################################################################
class Note < Tag
end

class Image < Tag
end

class Person < Tag
end

class Location < Tag
     	
	#http://ws.geonames.org/postalCodeSearch?placename=kaiserslaute&maxRows=10
     #http://local.yahooapis.com/MapsService/V1/geocode?appid=YahooDemo&street=701+First+Street&city=Sunnyvale&state=CA
end	

class Link < Tag
	#is_blog?
	#thumbnail
end

