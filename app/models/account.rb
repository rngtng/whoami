####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

# Class representing a webservice account. Every specific account implementation is inherited from Account and extended for specific API calls.
# The STI (Single Table Interhitance) Pattern is used for a clean structure. 
# An account belongs to an user and can have many resources.
class Account < ActiveRecord::Base
   extend InstanceVars #custom plugin to set account attributes easily
   
   belongs_to :user

   has_many   :resources,         :order => 'time DESC', :dependent => :destroy

   serialize  :token

   validates_associated  :user
   validates_presence_of :username

   delegate *Annotation.types.push( :annotations, :to => :resources )

   before_save :resources_count #update resource_counter

   #The color to use for this account  & Time the account needs update
   iattr_reader :color => "#000000", :outdated_after => 5.minutes
   iattr_reader_boolean :requires_auth, :requires_host , {:requires_user => true}, :requires_password


   ################### CALSS METHODS  ################################
   #factory method to create new Account instances easily
   def self.factory( type )
      class_name = type.capitalize + 'Account'
      redirect_to :controller => "user" and return unless defined? class_name.constantize
      class_name.constantize.new
   end

   #return all availables account types
   def self.types
      @types ||= subclasses.collect(&:to_s).collect( &:downcase ).collect { |s| s.sub( /account/, '' ) }
      @types.map ##return a copy!
   end

   #return accounts which needs an update. Filters can specified for account type and username
   def self.find_to_update( account_type = '', user_name = '%')
      account_type  = Account.types.include?( account_type ) ? account_type : ''
      user_name      = User.all_logins.include?( user_name ) ? user_name : '%'
      account = (account_type.capitalize + 'Account').constantize
      time    = Time.now - account.outdated_after
      Account.transaction do
         a = account.find( :first, :conditions => [ 'users.login LIKE ? AND accounts.updated_at < ?', user_name, time ], :include => [ :user ] )
         a.save if a #update timestamp -> no other workers get this feed
         return a
      end
   end

   ################### FETCH STUFF   ###################################
   # Major fetch resources and fetch details method called by worker
   def worker_fetch_resources
      (resources_count > 0 ) ? fetch_resources : fetch_resources_init
      fetch_resources_detail
      save #update time and resources.count
   end

   # Destroy account resources and get them new
   #def fetch_resources!
   #   resources.destroy_all
   #   save
   #   fetch_resources_init
   #end

   # Get resources from this account via the API and save them to database.
   def fetch_resources( max_runs = 0, run = 0, updated = false ) #if max == 0 go for unlimited runs
      return fetch_resources_fallback unless auth?
      return updated if max_runs > 0 and run == max_runs
      raw_resources(run).each do | resource |
         i = Resource.factory( type, :raw_data => resource )
         updated = self.resources << i || updated
      end
      return updated unless updated ## nothing more to fetch -> return
      sleep 0.3 ## prevent API DOS
      fetch_resources( max_runs, run + 1 ) #check if there are more to fetch
   end

   # Fallback method in case resources can not be fetched e.g. in case of wrong auth. 
   # Typically this is to fetch the RSS/ATOM feed
   def fetch_resources_fallback
      result = Hpricot.XML( open( feed ) ) #more infos but less resources  max. 31    #TODO: loop trough annotations to get even more!
      (result/:item).each  do |resource|
         i = Resource.factory( type, :feed=> resource )
         self.resources << i
      end
   end
   
   #################### GET STUFF #############################
   #Number of resources the account has
   def resources_count
      self.resources_count = resources.count
   end

   # Type of the account
   def type
      @type ||= self.class.to_s.downcase.sub( /account/, '' )
   end

   # All information about this account
   def info
      info = []
      info << "Type: #{type} - #{username}"
      info << "User: #{user.name}"
      #TODO!! info << "Resources: #{resources.count} - #{valid_resources.count} are valid "
      info.join("\n")
   end

   # Dummy method: for resources to process. Needs to be implemented by each subclass
   def raw_resources( run = 0)
   end

   # Dummy method: for feed (ATOM/RSS) to process. Needs to be implemented by each subclass
   def feed
   end

   # Checks if user is authorized
   def auth?
      !self.requires_password? or ( !password.nil? && !password.empty? )
      ##TODO check if logged in
   end

   # Checks if account is up to date
   def up_to_date?
      updated_at > ( Time.now - outdated_after )
   end

   ############################################################
   private
   #called if no resources yet..
   def fetch_resources_init
      fetch_resources
   end

   #get more details about the resources
   def fetch_resources_detail
   end

   # Dummy method: api to call
   def api
   end

   # Get api key from config file
   def api_key( what = :key )
      begin
         ApiKeys.get( type => what )
      rescue
         nil
      end
   end
end

###############################################################################
# Implementation of a Flickr account. API access is done via the rflickr gem.
class FlickrAccount < Account
   @color = "#FF0000"
   @requires_auth = true

   #set authentification infos
   def auth( params )
      api.auth.frob = params[:frob]
      api.auth.getToken
      self.token = api.auth.token
      self.username = token.user.username
   end

   #get authentification link
   def auth_link
      api.auth.getFrob
      api.auth.login_link( 'read' )
   end

   #check if token is authenticated
   def auth?
      api.auth.token
   end

   #get raw resources via API, default 15 photos per run/page
   def raw_resources( run = 0, per_page = 15 )  #run = number of pages - 1
      user = token.user.nsid
      annotations = nil
      annotation_mode = nil
      text = nil
      min_upload_date = nil
      max_upload_date = nil
      min_taken_date = nil
      max_taken_date = nil
      license = nil
      extras = "date_taken,annotations"
      sort = nil
      api.photos.search( user, annotations, annotation_mode, text, min_upload_date, max_upload_date, min_taken_date, max_taken_date, license, extras, per_page, run + 1, sort )
   end
   alias photos raw_resources

   #feed url for fallback
   def feed
      "http://api.flickr.com/services/feeds/photos_public.gne?id=#{username}&format=rss_200"
   end

   private
   #get api access instance
   def api
      @api ||= Flickr.new( 'dummy', api_key, api_key( :secret ) )
      @api.auth.token ||= token if token
      @api
   end
   alias flickr api

   #get resources details, e.g. title, tags etc..
   def fetch_resources_detail( limit = 100 )
      resources.find_incomplete( :all, :limit => limit ).each do | resource |
         resource.detail_data = api.photos.getInfo( resource.imgid, resource.secret ) #split to id,secret -> it is much faster!!
         begin
            data = get_location( resource.imgid )
            resource.annotate( :geo => {:lat => data['latitude'], :lng => data['longitude']} )
         rescue Exception =>  e
            puts e.message
         end
         sleep 0.1 ## prevent API DOS
         resource.save
      end
   end

   #get location data from raw api data
   def get_location( id )
      res = api.call_method('flickr.photos.geo.getLocation', 'photo_id'=> id )
      res.elements['/photo'].each_element do |location|
         return location.attributes
      end
   end
end


######################################################################################################
# Implementation of a Youtube account. API access is done via the youtube gem.
class YoutubeAccount < Account
   @color = "#00FF00"

   #get raw resources via API
   def raw_resources(run = 0)
      case run
      when 0 : api.videos_by_user( username ) #TODO paging support??
         #when 1 : api.favorite_videos( username )
      else []
      end
   end
   alias videos raw_resources

   private
   #get api access instance
   def api
      @api ||= YouTube::Client.new api_key
   end
   alias youtube api
end

######################################################################################################
# Implementation of a LastFM account. API access is done via the mylastfm gem.
# TODO: just fetch albums to speed up process
class LastfmAccount < Account
   @color = "#D01F3C"
   @outdated_after = 3.minutes

   #feed url for fallback
   def feed
      "http://ws.audioscrobbler.com/1.0/user/#{username}/recenttracks.rss"
   end

   #get raw resources via API
   def raw_resources(run = 0)
      #api.user_recenttracks()
      return [] if run > 2
      api.user_tracks( run - 1 )
   end
   alias tracks raw_resources

   private
   #get api access instance
   def api
      @api ||= MyLastfm::Client.new username
   end
   alias lastfm api

   #get resources details, e.g. album
   def fetch_resources_detail( limit = 1000 )
      resources.find_incomplete( :all,  :limit => limit ).each do | track |
         puts "process track #{track.artist}, #{track.title}, #{track.time}"
         track.album = fetch_album( track.artist, track.title, track.time )
         track.save
      end
   end

   #fetche a album for a given atrist and track_title and stores it to cached albums.
   def fetch_album( artist, track_title, date)
      @cached ||= Hash.new
      album = find_album( artist, track_title )
      return album if album || @cached[date]
      api.user_albums( date ).each do | album |
         begin
            a = Cachedalbum.create!( :artist => album.artist, :title => album.title )
            a.album = api.album_info( album.artist, album.title )
            a.save
            sleep 0.3
         rescue
            #puts "!### #{album.artist}, #{album.title} already cached"
         end
      end
      @cached[date] = true
      find_album( artist, track_title )
   end

   # return the album details
   def fetch_albums_details
      Cachedalbum.find_all_by_album( nil ).each do | album |
         album.album = api.album_info( album.artist, album.title )
         album.save
      end
   end

   # return the album for a given atrist and track_title from cached albums.
   # TODO: maybe move this to gem??
   def find_album( artist, track_title )
      a = Cachedalbum.find_by_artist( artist, :conditions => [ "album LIKE ?", "%#{track_title}%" ])
      return nil unless a
      a.album
   end

   #TODO: def fetch_resources_fallback
   #   result = Hpricot.XML( open( feed ) ) #more infos but less resources  max. 31    #TODO: loop trough annotations to get even more!
   #   (result/:item).each  do |resource|
   #      i = Resource.factory( type, :feed=> resource )
   #      self.resources << i
   #   end
   #end
end

######################################################################################################
# Implementation of a Del.icio.us account. API access is done via the mydelicious gem.
class DeliciousAccount < Account
   @color = "#0000FF"
   @requires_password = true

   #TODO:  #requires_username  #can_have_password

   #feed url for fallback
   def feed
      "http://del.icio.us/rss/#{username}"
   end

   #get raw resources via API
   def raw_resources(run = 0)
      case run
      when 0 : api.posts_recent( nil, 100 )
      when 1 : api.posts_all if run == 1
      else []
      end
   end
   alias bookmarks raw_resources

   private
   #get api access instance
   def api
      @api ||= MyDelicious::Client.new username, password
   end
   alias delicious api
end

######################################################################################################
# Implementation of a Blog/Wordpress account. API access is done via Feed or the XML-RPC client
class BlogAccount < Account
   # @color = "#000000" #TODO default??
   @requires_host = true
   @requires_password = true

   #feed url for fallback
   def feed
      UrlChecker.get_feed_url( host )
   end

   #get raw resources via API
   def raw_resources( run = 0, blog_id = 1)
      count = (run+1) * 10
      api.call('metaWeblog.getRecentPosts', blog_id, username, password, count)
   end
   alias posts raw_resources

   #checks if user is authentificated
   def auth?
      api and super
      ##TODO check if logged in
   end

   private
   #get api access instance
   def api
      url = UrlChecker.get_xmlrpc_url( host )
      @api ||= XMLRPC::Client.new2( url ) if url
   end
   alias blog api

   #intial resource fetch 
   def fetch_resources_init
      fetch_resources( 100, 50 ) #get 500 posting, until we got more than 1000
   end

   # What to do if resources can not be fetched e.g. in case of wrong auth
   def fetch_resources_fallback
      f = FeedNormalizer::FeedNormalizer.parse( open( feed ) )
      f.items.each  do |resource|
         i = Resource.factory( type, :feed => resource )
         self.resources << i
      end
   end
end

#class FeedAccount < Account
#   @color = "#FFFF00"
#   @requires_host = true
#   @requires_user = false
#
#   def raw_resources( run = 0, blog_id = 1)
#      count = (run+1) * 10
#      api.call('metaWeblog.getRecentPosts', blog_id, username, password, count)
#   end
#   alias posts raw_resources
#
#   private
#   def api
#      url = UrlChecker.get_xmlrpc_url( host )
#      @api ||= XMLRPC::Client.new2( url )
#   end
#   alias blog api
#
#   def fetch_resources_init
#      fetch_resources( 100, 50 ) #get 500 posting, until we got more than 1000
#   end
#end

######################################################################################################
#class YahoosearchAccount < Account
#   @color = "#9BE5E9"
#
#   def raw_resources( run = 0 )
#      count = (run+1 ) * 5
#      url = "http://api.search.yahoo.com/WebSearchService/V1/webSearch?appid=YahooDemo&query=#{CGI::escape(username)}&results=#{count}"
#      #result = Hpricot.XML( open( url ) )
#      #(result%"result")
#   end
#end

#######################################################################################################
#class TwitterAccount < Account
#   @color = "#9BE5E9"
#   @requires_password = true
#
#   def raw_resources( run = 0 )
#      case run
#      when 0 : api.user_timeline
#      else []
#      end
#   end
#   alias timeline raw_resources
#
#   private
#   def api
#      @api ||= Twitter::Client.new(:login => username, :password => password)
#   end
#   alias twitter api
#end
#
#######################################################################################################
#class PlazesAccount < Account
#   @color = "#32648c"
#   @requires_password = true
#
#   def raw_resources( run = 0 )
#      count = (run+1) * 50 #number of days
#      api.trazes( count )
#   end
#   alias trazes raw_resources
#
#   private
#   def api
#      @api ||= Plazes::API.new( :username => username, :password => password, :developer_key => api_key)
#   end
#   alias plazes api
#end

