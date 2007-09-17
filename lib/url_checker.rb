####################
#
# $LastChangedDate: 2007-06-06 11:21:13 +0200 (Wed, 06 Jun 2007) $
# $Rev: 44 $
# by $Author: bielohla $

class UrlChecker

   #check given url for feed or xmlrpc support
   def self.check_url( url )
      return false if url.nil? or url.empty?
      # url = get_xmlrpc_url( url )
      #return url if url
      url = get_feed_url( url )
      return url if url
      false
   end

   #check if xmlrcp is supported
   def self.get_xmlrpc_url( url )
      url = "http://#{url.sub( 'http://', '')}"
      data = { :serendipity  => 'serendipity_xmlrpc.php', :wordpress =>  'xmlrpc.php' } #'blogger' <link rel="service.post" type="application/atom+xml" title="bensei.com - Atom" href="http://www.blogger.com/feeds/38630431/posts/default" />
      uri = URI.parse( url )
      data.each do |system_name, file_name|
         length = uri.path.rindex('/') ? uri.path.rindex('/') : 0
         xmlrpc_url = "#{uri.scheme}://#{uri.host}#{uri.path.slice(0, length)}/#{file_name}"
         begin
            page = open( xmlrpc_url )
            return xmlrpc_url if page.status.first == "200" #TODO: better check here. check for redirect
         rescue
         end
      end
      false #nothing found
   end

   #check if it is an feed url, if not try to extract the feed url
   def self.get_feed_url( url )
      url = "http://#{url.sub( 'http://', '')}"
      begin
         content = Hpricot.XML( open( url ) )
         return url if (content%"rss") or (content%"feed") #it is already an feed url -> return
         ['rss', 'atom'].each do |type|
            new_url = get_url( content, type )
            return new_url  if new_url
         end
      rescue Exception => e
      end
      false #nothing found
   end

   ###########################################################################################
   private
   def self.get_rss_url( content )
      get_url( content, 'rss')
   end

   def self.get_atom_url( content )
      get_url( content, 'atom')
   end

   def self.get_url( content, type )
      content = Hpricot.XML( open( content ) ) if content.is_a? String
      (content/"link[@rel='alternate']").each do |link|
         return link['href'] if link['type'] =~ Regexp.new("#{type}")
      end
      return false
   end


   def check_system( content )
      #wordpress: <meta name="generator" content="WordPress 2.2" />
      #<meta name="Powered-By" content="Serendipity v.0.9.1" />
      #<meta name="generator" content="Blogger" />
   end
end

