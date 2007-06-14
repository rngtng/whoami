####################
#
# $LastChangedDate: 2007-06-06 11:21:13 +0200 (Wed, 06 Jun 2007) $
# $Rev: 44 $
# by $Author: bielohla $

class UrlChecker

   def self.check_url( url )
      return false if url.nil? or url.empty?
      #url = get_xmlrpc_url( url )
      #return url if url
      url = get_feed_url( url )
      return url if url
      false
   end

   def self.get_xmlrpc_url( url )
      data = { :serendipity  => 'serendipity_xmlrpc.php', :wordpress =>  'xmlrpc.php' } #'blogger' <link rel="service.post" type="application/atom+xml" title="bensei.com - Atom" href="http://www.blogger.com/feeds/38630431/posts/default" />
      uri = URI.parse( "http://#{url.sub( 'http://', '')}" )
      data.each do |system_name, file_name|
         path = uri.path.slice(0, uri.path.rindex('/'))
         xmlrpc_url = "#{uri.scheme}://#{uri.host}#{path}/#{file_name}"
         begin
            page = open( xmlrpc_url )
            return xmlrpc_url if page.status.first == "200" #TODO better check here. check fpr redirect
         rescue
         end
      end
      false #nothing found
   end

   def self.get_feed_url( url )
      begin
         content = Hpricot.XML( open( url ) )
         ['rss', 'atom'].each do |type|
            new_url = get_url( content, type )
            return new_url  if new_url
         end
      rescue Exception => e
      end
      false #nothing found
   end

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
      #:wordpress: <meta name="generator" content="WordPress 2.2" />
      #<meta name="Powered-By" content="Serendipity v.0.9.1" />
      #<meta name="generator" content="Blogger" />
   end
end

