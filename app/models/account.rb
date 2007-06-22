####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

#require 'item'

class Account < ActiveRecord::Base
   belongs_to :user

   has_many   :items,         :order => 'time DESC', :dependent => :destroy
   has_many   :valid_items,   :order => 'time DESC', :class_name => 'Item', :conditions => Item.valid_condition  #:extend => TagCountsExtension,
   has_many   :invalid_items, :order => 'time DESC', :class_name => 'Item', :conditions => Item.valid_condition( false )  #:extend => TagCountsExtension,

   serialize  :token

   validates_associated  :user
   validates_presence_of :username

   delegate :requires_auth?, :requires_password?, :requires_host?, :daemon_update_time, :color, :to => :"self.class"
   delegate *Tag.types.push( :tags, :to => :valid_items )

   before_save :items_count #update item_counter

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
      begin
         account = (account_name.capitalize + 'Account').constantize
         time     = Time.now - account.daemon_update_time
         time_min = Time.now - 3.minutes #30.seconds  #minimum of 30 update age
         Account.transaction do
            a = account.find( :first, :conditions => [ 'users.login LIKE ? AND accounts.updated_at < ? AND ( accounts.items_count < 1 OR accounts.updated_at < ? )', username, time_min, time ], :include => [ :user, :items ] )
            a.save if a #update timestamp -> no other daemons get this feed
            return a
         end
      rescue
         raise "No such Account Type: " + account_name.capitalize + 'Account'
      end
   end

   #debug
   def self.first
      find :first
   end

   ###################### REQUIRES STUFF   ####################
   def self.requires_auth?
      @requires_auth ||= false
   end

   def self.requires_host?
      @requires_host ||= false
   end

   #wheter account password
   def self.requires_password?
      @requires_password ||= false
   end

   def self.daemon_update_time
      @daemon_update_time ||= 5.minutes
   end

   def self.color
      @color ||= "#000000"
   end

   ################### FETCH STUFF   ###################################
   #fecht items, fetch details, called by daemon
   def daemon_fetch_items
      (items_count > 0 ) ? fetch_items : fetch_items_init
      fetch_items_detail
      save #update time and items.count
   end

   #reset and get new items
   def daemon_fetch_items!
      items.destroy_all
      save
      daemon_fetch_items
   end

   def fetch_items( max_runs = 0, run = 0, updated = false ) #if max == 0 go for unlimited runs
      return fetch_items_fallback unless auth?
      return updated if max_runs > 0 and run == max_runs
      raw_items(run).each do | item |
         i = Item.factory( type, :raw_data => item )
         updated = self.items << i || updated
      end
      return updated unless updated ## nothing more to fetch -> return
      sleep 0.3 ## prevent API DOS
      fetch_items( max_runs, run + 1 ) #check if there are more to fetch
   end

   def fetch_items_fallback
      return fetch_feed #if user isn't auth
   end

   def fetch_feed
      f = FeedNormalizer::FeedNormalizer.parse( open( feed ) )
      f.items.each  do |item|
         i = Item.factory( type, :feed => item )
         self.items << i
      end
   end

   def fetch_rss  ##like fetch feed but far more details!
      result = Hpricot.XML( open( feed ) )
      (result/:item).each  do |item|
         i = Item.factory( type, :rss=> item )
         self.items << i
      end
   end

   #################### GET STUFF #############################
   def items_count
      self.items_count = items.count
   end

   def type #type of the item
      @type ||= self.class.to_s.downcase.sub( /account/, '' )
   end

   def info
      info = []
      info << "Type: #{type} - #{username}"
      info << "User: #{user.name}"
      info << "Items: #{items.count} - #{valid_items.count} are valid "
      info.join("\n")
   end

   def type
      self.class.to_s.downcase.sub( /account/, '' )
   end

   #items to process
   def raw_items( run = 0)
   end

   def feed
   end

   def auth?
      !self.requires_password? or ( !password.nil? && !password.empty? )
      ##TODO check if logged in
   end

   def uptodate?
      time     = Time.now - daemon_update_time
      time_min = Time.now - 30.seconds  #minimum of 30 update age
      ((updated_at > time_min) or (items_count > 1 and updated_at > time))
   end

   ############################################################
   private
   #called if no items yet..
   def fetch_items_init
      fetch_items
   end

   #get more details about the items
   def fetch_items_detail
   end

   #api to call
   def api
   end

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
   ############    AUTH Part   ############
   @requires_auth = true

   def auth( params )
      api.auth.frob = params[:frob]
      api.auth.getToken
      self.token = api.auth.token
      self.username = token.user.username
   end

   def auth_link
      api.auth.getFrob
      api.auth.login_link
   end

   def auth?
      api.auth.token
   end

   ############    Other Stuff   ############
   def raw_items( run = 0, per_page = 15 )  #run = number of pages - 1
      user = token.user.nsid
      tags = nil
      tag_mode = nil
      text = nil
      min_upload_date = nil
      max_upload_date = nil
      min_taken_date = nil
      max_taken_date = nil
      license = nil
      extras = "date_taken,tags"
      sort = nil
      api.photos.search( user, tags, tag_mode, text, min_upload_date, max_upload_date, min_taken_date, max_taken_date, license, extras, per_page, run + 1, sort )
   end
   alias photos raw_items

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

   def fetch_items_detail( limit = 100 )
      invalid_items.find( :all, :limit => limit ).each do | item |
         item.more_data = api.photos.getInfo( item.imgid, item.secret ) #split to id,secret -> it is much faster!!
         begin
            data = get_location( item.imgid )
            item.tag( :geo => {:lat => data['latitude'], :lng => data['longitude']} )
         rescue Exception =>  e
            puts e.message
         end
         sleep 0.1 ## prevent API DOS
         item.save
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

   def raw_items(run = 0)
      case run
      when 0 : api.videos_by_user( username ) #TODO pagin support??, count+1 )
         #when 1 : api.favorite_videos( username )
      else []
      end
   end
   alias videos raw_items

   ############################################
   private
   def api
      @api ||= YouTube::Client.new api_key
   end
   alias youtube api
end

######################################################################################################
class LastfmAccount < Account
   @color = "#D01F3C"
   @daemon_update_time = 5.minutes

   def feed
      "http://ws.audioscrobbler.com/1.0/user/#{username}/recenttracks.rss"
   end

   ############    Other Stuff   ############
   def raw_items(run = 0)
      #api.user_recenttracks()
      return [] if run > 2
      api.user_tracks( run - 1 )
   end
   alias tracks raw_items

   private
   def api
      @api ||= MyLastfm::Client.new username
   end
   alias lastfm api

   def fetch_items_detail( limit = 1000 )
      invalid_items.find( :all,  :limit => limit ).each do | track |
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
end

######################################################################################################
class DeliciousAccount < Account
   @color = "#0000FF"
   @requires_password = true

   def feed
      "http://del.icio.us/rss/#{username}"
   end

   ############    Other Stuff   ############
   def raw_items(run = 0)
      case run
      when 0 : api.posts_recent( nil, 100 )
      when 1 : api.posts_all if count == 1
      else []
      end
   end
   alias bookmarks raw_items

   private
   def api
      @api ||= MyDelicious::Client.new username, password
   end
   alias delicious api

   def fetch_items_fallback
      fetch_rss  #more infos but less items  max. 31    #TODO: loop trough tags to get even more!
   end
end

######################################################################################################

class BlogAccount < Account
   @color = "#000000"
   @requires_host = true
   @requires_password = true

   def feed
      UrlChecker.get_feed_url( host )
   end

   ############    Other Stuff   ############
   def raw_items( run = 0, blog_id = 1)
      count = (run+1) * 10
      api.call('metaWeblog.getRecentPosts', blog_id, username, password, count)
   end
   alias posts raw_items

   private
   def api
      url = UrlChecker.get_xmlrpc_url( host )
      @api ||= XMLRPC::Client.new2( url )
   end
   alias blog api

   def fetch_items_init
      fetch_items( 100, 50 ) #get 500 posting, until we got more than 1000
   end
end

######################################################################################################
#class YahoosearchAccount < Account
#   @color = "#9BE5E9"
#
#   def raw_items( run = 0 )
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
#   def raw_items( run = 0 )
#      case run
#      when 0 : api.user_timeline
#      else []
#      end
#   end
#   alias timeline raw_items
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
#   def raw_items( run = 0 )
#      count = (run+1) * 50 #number of days
#      api.trazes( count )
#   end
#   alias trazes raw_items
#
#   private
#   def api
#      @api ||= Plazes::API.new( :username => username, :password => password, :developer_key => api_key)
#   end
#   alias plazes api
#end

