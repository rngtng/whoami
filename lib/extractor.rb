####################
#
# $LastChangedDate: 2007-06-06 11:21:13 +0200 (Wed, 06 Jun 2007) $
# $Rev: 44 $
# by $Author: bielohla $

class Extractor

   #---------------------------------------------------------------------------------------------------------------------
   
   def self.get_tags( from  )
      self.tag_the_net( :text, from ) do |a, b| yield a, b; end
   end

   def self.get_tags_from_url( url )
      self.tag_the_net( :url, from ) do |a, b| yield a, b; end
   end
   
   # Extract urls and images
   def self.get_urls_and_images( from  )
      d = from.gsub( / www\./, ' http://www.').gsub( /'"/, '')
      URI::extract( d, 'http' ) do |url|
         type = ( url =~ /\.(png|jpg|gif)/ ) ? :image : :url
         yield type, url   #annotate( type => url )
      end
   end

   private
   # Extracts everthing fomr http://tagthe.net
   def self.tag_the_net( type, from  )
      from = from.gsub( /<[^>]*>/, '' ).gsub( /&[a-z0-9#]*;/, '' ) if type == :text
      doc = Hpricot.XML( open( "http://tagthe.net/api/?#{type}=#{CGI::escape(from)}" ) )
      [:topic, :person, :location, :language, :author].each do |type|
         (doc/"dim[@type='#{type}']/item").each do |resource|
            yield type, resource.inner_html
         end
      end
   end
end
