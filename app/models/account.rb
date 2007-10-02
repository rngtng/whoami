####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

# Class representing an account
#-- require 'resource'
class Account < ActiveRecord::Base
   belongs_to :user

   has_many   :resources,         :order => 'time DESC', :dependent => :destroy
   has_many   :valid_resources,   :order => 'time DESC', :class_name => 'Resource', :conditions => Resource.valid_condition  #:extend => AnnotationCountsExtension,
   has_many   :invalid_resources, :order => 'time DESC', :class_name => 'Resource', :conditions => Resource.valid_condition( false )  #:extend => AnnotationCountsExtension,

   serialize  :token

   validates_associated  :user
   #validates_presence_of :username

   delegate :requires_auth?, :requires_password?, :requires_user?, :requires_host?, :worker_update_time, :color, :to => :"self.class"
   delegate *Annotation.types.push( :annotations, :to => :valid_resources )

   before_save :resources_count #update resource_counter

   ################### CALSS METHODS  ################################
   def self.factory( type )
      class_name = type.capitalize + 'Account'
      redirect_to :controller => "user" and return unless defined? class_name.constantize
      class_name.constantize.new
   end

   def self.types
      @types ||= subclasses.collect(&:to_s).collect( &:downcase ).collect { |s| s.sub( /account/, '' ) }
      @types.map ##return a copy!
   end

   def self.find_to_update( account_name = '', username = '%')
      account_name  = Account.types.include?( account_name ) ? account_name : ''
      username      = User.all_logins.include?( username ) ? username : '%'
      account = (account_name.capitalize + 'Account').constantize
      time     = Time.now - account.worker_update_time
      time_min = Time.now - 3.minutes #30.seconds
      Account.transaction do
         a = account.find( :first, :conditions => [ 'users.login LIKE ? AND accounts.updated_at < ? AND ( accounts.resources_count < 1 OR accounts.updated_at < ? )', username, time_min, time ], :include => [ :user ] )
         a.save if a #update timestamp -> no other workers get this feed
         return a
      end
   end


   ###################### REQUIRES STUFF   ####################
   # Wheter account requires auth
   def self.requires_auth?
      @requires_auth ||= false
   end

   # Wheter account requires host
   def self.requires_host?
      @requires_host ||= false
   end

   # Wheter account requires host
   def self.requires_user?
      @requires_user ||= true
   end

   # Wheter account requires password
   def self.requires_password?
      @requires_password ||= false
   end

   # Time account needs update
   def self.worker_update_time
      @worker_update_time ||= 5.minutes
   end

   # The color to use for this account
   def self.color
      @color ||= "#000000"
   end

   ################### FETCH STUFF   ###################################
   # Fetch resources, fetch details, called by worker
   def worker_fetch_resources
      (resources_count > 0 ) ? fetch_resources : fetch_resources_init
      fetch_resources_detail
      save #update time and resources.count
   end

   # Destroy account resources and get them new
   def fetch_resources!
      resources.destroy_all
      save
      fetch_resources_init
   end

   # Get resources from this account
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

   # What to do if resources can not be fetched e.g. in case of wrong auth
   def fetch_resources_fallback
      result = Hpricot.XML( open( feed ) ) #more infos but less resources  max. 31    #TODO: loop trough annotations to get even more!
      (result/:item).each  do |resource|
         i = Resource.factory( type, :feed=> resource )
         self.resources << i
      end
   end
   #################### GET STUFF #############################
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
      info << "Resources: #{resources.count} - #{valid_resources.count} are valid "
      info.join("\n")
   end

   # Resources to process
   def raw_resources( run = 0)
   end

   def feed
   end

   def auth?
      !self.requires_password? or ( !password.nil? && !password.empty? )
      ##TODO check if logged in
   end

   # Checks if account is up to date
   def up_to_date?
      time     = Time.now - worker_update_time
      time_min = Time.now - 30.seconds  #minimum of 30 update age
      ((updated_at > time_min) or (resources_count > 1 and updated_at > time))
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

   #api to call
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
class FlickrAccount < Account
   @color = "#FF0000"
   @requires_auth = true

   def auth( params )
      api.auth.frob = params[:frob]
      api.auth.getToken
      self.token = api.auth.token
      self.username = token.user.username
   end

   def auth_link
      api.auth.getFrob
      api.auth.login_link( 'read' )
   end

   def auth?
      api.auth.token
   end

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

   def feed
      "http://api.flickr.com/services/feeds/photos_public.gne?id=#{username}&format=rss_200"
   end

   private
   def api
      @api ||= Flickr.new( 'dummy', api_key, api_key( :secret ) )
      @api.auth.token ||= token if token
      @api
   end
   alias flickr api

   def fetch_resources_detail( limit = 100 )
      invalid_resources.find( :all, :limit => limit ).each do | resource |
         resource.more_data = api.photos.getInfo( resource.imgid, resource.secret ) #split to id,secret -> it is much faster!!
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

   def get_location( id )
      res = api.call_method('flickr.photos.geo.getLocation', 'photo_id'=> id )
      res.elements['/photo'].each_element do |location|
         return location.attributes
      end
   end
end


######################################################################################################
class YoutubeAccount < Account
   @color = "#00FF00"

   def raw_resources(run = 0)
      case run
      when 0 : api.videos_by_user( username ) #TODO paging support??, count+1 )
         #when 1 : api.favorite_videos( username )
      else []
      end
   end
   alias videos raw_resources

   private
   def api
      @api ||= YouTube::Client.new api_key
   end
   alias youtube api
end

######################################################################################################
class LastfmAccount < Account
   @color = "#D01F3C"
   @worker_update_time = 5.minutes

   def feed
      "http://ws.audioscrobbler.com/1.0/user/#{username}/recenttracks.rss"
   end

   def raw_resources(run = 0)
      #api.user_recenttracks()
      return [] if run > 2
      api.user_tracks( run - 1 )
   end
   alias tracks raw_resources

   private
   def api
      @api ||= MyLastfm::Client.new username
   end
   alias lastfm api

   def fetch_resources_detail( limit = 1000 )
      invalid_resources.find( :all,  :limit => limit ).each do | track |
         puts "process track #{track.artist}, #{track.title}, #{track.time}"
         track.album = fetch_album( track.artist, track.title, track.time )
         track.save
      end
   end

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

   def fetch_albums_details
      Cachedalbum.find_all_by_album( nil ).each do | album |
         album.album = api.album_info( album.artist, album.title )
         album.save
      end
   end

   def find_album( artist, track_title )
      a = Cachedalbum.find_by_artist( artist, :conditions => [ "album LIKE ?", "%#{track_title}%" ])
      return nil unless a
      a.album
   end

   #TODO
   #def fetch_resources_fallback
   #   result = Hpricot.XML( open( feed ) ) #more infos but less resources  max. 31    #TODO: loop trough annotations to get even more!
   #   (result/:item).each  do |resource|
   #      i = Resource.factory( type, :feed=> resource )
   #      self.resources << i
   #   end
   #end
end

######################################################################################################
class DeliciousAccount < Account
   @color = "#0000FF"
   @requires_password = true

   def feed
      "http://del.icio.us/rss/#{username}"
   end

   def raw_resources(run = 0)
      case run
      when 0 : api.posts_recent( nil, 100 )
      when 1 : api.posts_all if run == 1
      else []
      end
   end
   alias bookmarks raw_resources

   private
   def api
      @api ||= MyDelicious::Client.new username, password
   end
   alias delicious api
end

######################################################################################################

class BlogAccount < Account
   @color = "#000000"
   @requires_host = true
   @requires_password = true

   def feed
      UrlChecker.get_feed_url( host )
   end

   def raw_resources( run = 0, blog_id = 1)
      count = (run+1) * 10
      api.call('metaWeblog.getRecentPosts', blog_id, username, password, count)
   end
   alias posts raw_resources

   def auth?
      api and super
      ##TODO check if logged in
   end

   private
   def api
      url = UrlChecker.get_xmlrpc_url( host )
      @api ||= XMLRPC::Client.new2( url ) if url
   end
   alias blog api

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

