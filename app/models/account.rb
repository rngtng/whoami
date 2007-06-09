####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

#require 'item'

class Account < ActiveRecord::Base
   belongs_to :user

   has_many   :items,         :order => 'time DESC'
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
         time_min = Time.now - 30.seconds  #minimum of 30 update age
         Account.transaction do
            a = account.find( :first, :conditions => [ 'users.name LIKE ? AND accounts.updated_at < ? AND ( accounts.items_count < 1 OR accounts.updated_at < ? )', username, time_min, time ], :include => [ :user, :items ] )
            a.save if a #update timestamp -> no other daemons get this feed
            return a
         end
      rescue
         raise "No such Account Type: " + account_name.capitalize + 'Account'
      end
   end

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
   def fetch_all
      fetch_profile
      fetch_tags
      fetch_items
   end

   #fecht items, fetch details, called by daemlin
   def daemon_fetch_items
      (items_count > 0 ) ? fetch_items : fetch_items_init
      fetch_details
      save
   end

   #reset and get new items
   def fetch_items!
      items.destroy_all
      save
      fetch_items_init
   end

   def items_count
      self.items_count = items.count
   end

   def fetch_items( count = 0, max = 0 )
      return fetch_item_fallback unless auth?
      return false if max > 0 and count == max
      updated = false
      raw_items(count).each do | item |
         i = Item.factory( type, :rawdata => item )
         updated = self.items << i || updated
      end
      return updated unless updated ## no more to update, return
      sleep 0.3 ## prevent API DOS
      fetch_items( count + 1, max ) #checking if there are more..
   end

   def fetch_item_fallback
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
   #type of the item
   def type
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
   def raw_items( count = 0)
   end

   def feed
   end

   def auth?
      !self.requires_password? or ( !password.nil? && !password.empty? )
      ##check if logged in
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
   def fetch_details
   end

   #api to call
   def api
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
   def raw_items( count = 0, per_page = 15 )  #count = number of pages - 1
      #@photos ||= Array.new #@photos[count] ||=
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
      count += 1  #pageno start by 1
      api.photos.search( user, tags, tag_mode, text, min_upload_date, max_upload_date, min_taken_date, max_taken_date, license, extras, per_page, count, sort )
   end
   alias photos raw_items

   def feed
      "http://api.flickr.com/services/feeds/photos_public.gne?id=#{username}&format=rss_200"
   end

   private
   def api
      @api ||= Flickr.new( 'dummy', '4e49a06e0e815680660e1e37ae4a1a2d', '9390237b2c854292' )
      @api.auth.token ||= token if token
      @api
   end
   alias flickr api

   def fetch_details( limit = 100 )
      invalid_items.find( :all,  :limit => limit ).each do | item |
         item.data_add( api.photos.getInfo( item.imgid, item.secret ) ) #split to id,secret -> it is much faster!!
         #item.geo_add( get_location( item ) )
         sleep 0.1 ## prevent API DOS
         item.save
      end
   end

   def get_location( item )
      begin
         res = api.call_method('flickr.photos.geo.getLocation', 'photo_id'=> item.imgid )
         res.elements['/photo'].each_element do |location|
            return location.attributes
         end
      rescue
         []
      end
   end
end


######################################################################################################
class YoutubeAccount < Account
   @color = "#00FF00"
   ############    Other Stuff   ############
   def profile
      api.profile( username )
   end

   def raw_items(count = 0)
      return [] if username.nil?
      #return api.favorite_videos( username ) if count == 0
      return api.videos_by_user( username ) if count == 0 #TODO pagin support??, count+1 )
      return []
   end
   alias videos raw_items

   def auth?
      true
   end

   def feed #no feed needed as there is always
      "http://youtube.com/rss/user/#{username}/videos.rss"
   end

   ############################################
   private
   def api
      @api ||= YouTube::Client.new 'G1Wl5IDX66M'
   end
   alias youtube api
end

######################################################################################################
class LastfmAccount < Account
   @color = "#0000FF"
   @daemon_update_time = 5.minutes

   def feed
      "http://ws.audioscrobbler.com/1.0/user/#{username}/recenttracks.rss"
   end

   ############    Other Stuff   ############
   def raw_items(count = 0)
      api.user_tracks( count )
   end
   alias tracks raw_items

   private
   def api
      @api ||= MyLastfm::Client.new username
   end
   alias lastfm api

   def fetch_details( limit = 1000 )
      invalid_items.find( :all,  :limit => limit ).each do | track |
         #puts "process track #{track.artist}, #{track.title}, #{track.time}"
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
   @color = "#0000dd"
   @requires_password = true

   def feed
      "http://del.icio.us/rss/#{username}"
   end

   def json
      "http://del.icio.us/feeds/json/#{username}?count=100&raw"
   end

   ############    Other Stuff   ############
   def raw_items(count = 0)
      return api.posts_recent( nil, 100 ) if count == 0
      return api.posts_all if count == 1
      return Array.new
   end
   alias bookmarks raw_items

   private
   def api
      @api ||= MyDelicious::Client.new username, password
   end
   alias delicious api

   def fetch_item_fallback
      fetch_rss  #more infos but less items
      #TODO: loop trough tags to get even more!
      #fetch_json #more items but less infos
   end

   def fetch_json
      data = open( json ).readline
      JSON.parse(data).each  do |item|
         i = Item.factory( type, :json => item )
         self.items << i
      end
   end
end

######################################################################################################

class BlogAccount < Account
   @color = "#FF0099"
   @requires_host = true
   @requires_password = true

   def feed
      UrlChecker.get_feed_url( host )
   end

   ############    Other Stuff   ############
   def raw_items( count = 0, blog_id = 1)
      count = (count+1) * 10
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
      fetch_items( 500, 100 ) #get 500 posting, increase by 100 if more..
   end
end

######################################################################################################
class YahoosearchAccount < Account
   @color = "#9BE5E9"

   def raw_items( count = 1 )
      url = "http://api.search.yahoo.com/WebSearchService/V1/webSearch?appid=YahooDemo&query=#{CGI::escape(username)}&results=#{count}"
      #TODO use hpricot here!
      #result = Net::HTTP.get_response( URI.parse( url ) ).body
      #result = XmlSimple.xml_in( result,{ 'ForceArray' => [ 'Result' ] } )
      #result[ 'Result' ]
   end
end

######################################################################################################
class TwitterAccount < Account
   @color = "#9BE5E9"
   @requires_password = true

   def raw_items( count = 0 )
      return api.user_timeline if count == 0
      []
   end
   alias timeline raw_items

   private
   def api
      @api ||= Twitter::Client.new(:login => username, :password => password)
   end
   alias twitter api
end

######################################################################################################
class PlazesAccount < Account
   @color = "#32648c"
   @requires_password = true

   def raw_items( count = 0 )
      count = (count+1) * 50 #number of days
      api.trazes( count )
   end
   alias trazes raw_items

   private
   def api
      @api ||= Plazes::API.new( :username => username, :password => password, :developer_key => '7d4d6ecd009b4d135375457403f5231f')
   end
   alias plazes api
end

