class Account < ActiveRecord::Base
        belongs_to :user 
        has_many   :items, :extend => TagCountsExtension
	serialize  :token
        
        #validates_presence_of :username
	#Accout.find( :all).each( &:items_count! )
	
	################### CALSS METHODS  ################################
	def self.factory( type )
	   class_name = type.capitalize + 'Account'
	   redirect_to :controller => "user" and return unless defined? class_name.constantize
	   class_name.constantize.new
	end
	
        def self.types
	    subclasses.collect(&:to_s).collect( &:downcase ).collect { |s| s.sub( /account/, '' ) }
        end
        
	def self.find_to_update( account_name = '')
		account = (account_name.capitalize + 'Account').constantize
		time = Time.now - account.daemon_update_time
		account.find( :first, :conditions => [ 'updated_at < ?', time ], :include => :user ) 
	end	
	
	def self.daemon_update_time
		15.minutes
	end
	
	def daemon_sleep_time
		15.seconds
	end
	################### FETCH STUFF   ###################################
	def fetch_all
		fetch_profile
		fetch_tags
		fetch_items
	end
	
	#fecht items, fetch details
	def daemon_fetch_items
             (items_count > 0 ) ? fetch_items : fetch_items_init
	     fetch_details
	     save	
	end
	
	#called if no items yet..
	def fetch_items!
		items.destroy_all
		items_count!
		fetch_items_init
	end
	
	def items_count!
		self.items_count = items.count
                save
		items_count
	end	
	
	def fetch_items( count = 0, max = 0 )
	  return false if max > 0 and count == max 
	  updated = false	
          raw_items(count).each do | item |
             i = Item.factory( type, :data => item )
             updated = self.items << i || updated
	   end
	   return updated unless updated ## no more to update, return
	   sleep 0.3 ## prevent API DOS
	   fetch_items( count + 1, max ) #checking if there are more..
	   #### items(:refresh).size
	end	

	def fetch_profile
	end

        def fetch_tags
        end
	
	def fetch_friends
        end
	
	def fetch_feed
		parse_feed( open( feed ) )
        end
	#################### GET STUFF #############################
	def get_items( *params )
		items.find_all_by_complete( true, *params )
	end
	
	def get_tags
		#items
		Item.tag_counts( :conditions => [ "items.account_id = ? ", self.id ] )
	end
	
##Select name, account_id, Count(*) AS o FROM tags AS t
## INNER JOIN taggings As t2 
##ON t.id = t2.tag_id
##INNER JOIN items AS i
##ON i.id = t2.taggable_id
##GROUP BY name
##ORDER BY o
	
	###################### REQUIRES STUFF   ####################
	def requires_auth?
	    false
        end
	
	def requires_host?
	    false
        end
	
	#wheter account password
	def requires_password?
	    false
        end
	
	############################################################
	def type
	   self.class.to_s.downcase.sub( /account/, '' )
	end	
	
	#items to process
	def raw_items( count = 0)
	end
	
	def tags
	end
	
	def friends
	end

        def feed
	end

        def profile
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
	
	#parse a rss/atom feed
	def parse_feed( content )
          feed = FeedNormalizer::FeedNormalizer.parse( content )  
          feed.items.each  do |item|
            i = FeedItem.new( :data => item )
            self.items << i
          end
        end 
end

###############################################################################

class FlickrAccount < Account
	############    AUTH Part   ############
	def requires_auth?
		true
        end
	
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
	
	############    Fetch Stuff   ############
	def fetch_profile
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
	
	#def tags
	#    api.tags.getListUser( user )
	#end
	
	#private
	def api
	   @api ||= Flickr.new( 'dummy', '4e49a06e0e815680660e1e37ae4a1a2d', '9390237b2c854292' )
	   @api.auth.token ||= token if token
	   @api
	end
	alias flickr api
	
	def fetch_details( limit = 100 )
	    items.find_all_by_complete( false, :limit => limit ).each do | item |
		item.data_add( api.photos.getInfo( *item.dataid.split(/:/) ) ) #split to id,secret -> it is much faster!!
		sleep 0.3 ## prevent API DOS
		item.save
	    end	
	end
end


######################################################################################################

class YoutubeAccount < Account
	############    Other Stuff   ############
	def profile
	   api.profile( username )
        end
	
	def raw_items(count = 0)
	    return api.favorite_videos( username ) if count == 0
	    return api.videos_by_user( username ) if count == 1 #TODO pagin support??, count+1 )
	    return Array.new
        end
	alias videos raw_items
	
	def feed
	   "http://youtube.com/rss/user/#{username}/videos.rss"
        end
	
	############################################
	#private
	def api
	   @api ||= YouTube::Client.new 'G1Wl5IDX66M'
	end
	alias youtube api
end	

######################################################################################################

class LastfmAccount < Account
	def self.daemon_update_time
		5.minutes
	end
	############    Get Stuff   ############
	def feed
	   "http://ws.audioscrobbler.com/1.0/user/#{username}/recenttracks.rss"
        end
	
	def fetch_profile
	  #url = "1.0/user/#{username}/profile.xml"
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
	   items.find_all_by_complete( false, :limit => limit ).each do | track |
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
        ############    Get Stuff   ############
	def feed
 	   "http://del.icio.us/rss/#{username}"	 
        end
	
	def fetch_profile
	  #url = "1.0/user/#{username}/profile.xml"
	end  
	
	def requires_password?
	    true
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
end

######################################################################################################

class BlogAccount < Account
        ############    Get Stuff   ############
	def fetch_feed
	   #TODO parse( posts( 10 ) )
        end
	
	def fetch_profile
	end  
	
	def requires_host?
	    true
        end
	
	def requires_password?
	    true
        end
	
	def data
		@blog_types = Hash.new
		@blog_types = { "wordpress" => "xmlrpc.php" }	
	end	
		
	#def host
	#	#{self.host}
	#end
	
	############    Other Stuff   ############
	
	def raw_items( count = 0, blog_id = 1)
		count = (count+1) * 10 
		api.call('metaWeblog.getRecentPosts', blog_id, username, password, count)
	end
	alias posts raw_items
	
	#private
	def api
	    @api ||= XMLRPC::Client.new2( host )
        end
	alias blog api
	
	def fetch_items_init
	    fetch_items( 500, 100 ) #get 500 posting, increase by 100 if more..
        end
end	

######################################################################################################

class AmazonAccount < Account
        ############    Get Stuff   ############
	def fetch_feed
	   #TODO parse( posts( 10 ) )
        end
	
	def fetch_profile
	end  
	
	def requires_host?
	    false
        end
	
	def requires_password?
	    false
        end
	
	############    Other Stuff   ############
	
	def raw_items( count = 0, blog_id = 1)
		return if count > 0
		api.customer_content_lookup( userid, { :response_group =>'CustomerFull'} )
	end
	alias reviews raw_items
	
	#private
	def userid
		return @userid if @userid
		r = api.customer_content_search_by_email( username )
		@userid = (r.doc/"customers/request/customercontentsearchrequest/email").inner_html
	end
	
	def api
	    #secret = '9AcMQU+m21fWVlTtGSQbqnNPchA8ddwX75XUIH6h'	
	    Amazon::Ecs.options = {:aWS_access_key_id => '1MC9JDPY4WSNTJAEZX02', :country => 'de' }	
	    @api ||= Amazon::Ecs
        end
	alias amazon api
end

