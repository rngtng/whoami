class Account < ActiveRecord::Base
        belongs_to :user 
        has_many   :items
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
	
	def fetch_items( count = 0, step = 1)
	  updated = false	
          raw_items(count).each do | item |
             i = Item.factory( type, :data => item )
             updated = self.items << i || updated
	   end
	   updated
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

###################################################################################################### 

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

        def fetch_tags
	   #tags.each do | item |
	   #  i = Tag.new( )
           #  updated = self.tags << i || updated
	   #end	
        end
	
	def fetch_items( count = 1, step = 1 )  #count = number of pages  
	   updated = false
	   raw_items( count ).each do | item |
	     i = Item.factory( type, :dataid => [item.id, item.secret].join(':'), :time => Time.now )
             updated = self.items << i || updated
	   end
	   return unless updated ## no more to update
	   sleep 1 ## prevent API DOS
	   fetch_items( count + step, step ) unless count == raw_items( count ).pages
	end 
	
	############    Other Stuff   ############
	def raw_items( count = 1 )  #count = number of pages  
	    @photos ||= Array.new	
	    user = token.user.nsid
            tags = nil
            tag_mode = nil
            text = nil
            min_upload_date = nil
            max_upload_date = nil
            min_taken_date = nil
            max_taken_date = nil
            license = nil
            extras = nil
            per_page = 15
            sort = nil
	    @photos[count] ||= api.photos.search( user, tags, tag_mode, text, min_upload_date, max_upload_date, min_taken_date, max_taken_date, license, extras, per_page, count, sort )
        end
	#alias photos raw_items
	
	def feed
	   "http://api.flickr.com/services/feeds/photos_public.gne?id=#{username}&format=rss_200"	
        end
	
	def tags
	    api.tags.getListUser( user )
	end
	
	private
	def api
	   @api ||= Flickr.new( 'dummy', '4e49a06e0e815680660e1e37ae4a1a2d', '9390237b2c854292' )
	   @api.auth.token ||= token if token
	   @api
	end
	#alias flickr api
	
	def fetch_details( limit = 100 )
	    items.find_all_by_complete( false, :limit => limit ).each do | item |
		item.data  = api.photos.getInfo( *item.dataid.split(/:/) ) #split to id,secret -> it is much faster!!
		sleep 0.1 ## prevent API DOS
		item.save
	    end	
	end
end

######################################################################################################

class YoutubeAccount < Account
        ############    Get Stuff   ############
	def fetch_profile
	   api.profile( username )
        end
	
	############    Other Stuff   ############
	def raw_items(count = 0)
	    api.videos_by_user( username )
        end
	#alias videos raw_items
	
	def feed
	   "http://youtube.com/rss/user/#{username}/videos.rss"
        end
	
	############################################
	private
	def api
	   @api ||= YouTube::Client.new 'G1Wl5IDX66M'
	end
	#alias youtube api
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
	
	def fetch_items( count = 0)
	   updated = super( count )	
	   return unless updated ## no more to update, return even tracks ist empty
	   sleep 1 ## prevent API DOS
	   fetch_items( count + 1 )
        end
	
	############    Other Stuff   ############
	def raw_items(count = 0)
		api.user_tracks( count )
	end
	#alias tracks raw_items
	
	private
	def api
	   @api ||= MyLastfm::Client.new username
	end
	#alias lastfm api
	
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
		     sleep 1 
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
            api.posts_all
        end
	#alias bookmarks raw_items
	
	private
	def api
	   @api ||= MyDelicious::Client.new username, password
	end
	#alias delicious api
end

######################################################################################################

class EbayAccount < Account
	############    Get Stuff   ############
	def fetch_feed
        end
	
	def fetch_profile
	end  
	
	############    Other Stuff   ############
	def raw_items(count = 0)
		api.fetch_my_ebay_buying
                #ebay.fetch_my_ebay_selling
	end
	#alias auctions raw_items
	
	private
	def api
	  return @api if @api	
	  ebay_configure
	  @api = Ebay::Api.new
	end
	#alias ebay api


        def ebay_configure
          Ebay::Api.configure do |ebay|
            ebay.auth_token = "AgAAAA**AQAAAA**aAAAAA**ij8+Rg**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wJkYWmD5aCqAidj6x9nY+seQ**ZS8AAA**AAMAAA**VqUh/uYk3RMyOl22T4WQNxOrk43FijC5ROGMV378Gocd9lqf1DCBAkp1GwE6Hr7dguGb+GzpJv0DH1EiZ4/3KnNKMB7exQlKjCrK34UHZ7YxNLBBmRJjnD+wJ0p3UuN1yWFl5dg/dAcaZcxNv1qyYx6CbCiLtj4ljzaI90kA65KIDyaxmasQCTMN41cwcRO0VbIAz30II+qUbKC08iLXsuKVIJXIf57vJC8ee36Y4avDcDJH11/VTlh/B8biImYfVXzmf5f7zMkQC7aqrcv/qm8gPYfQMe+5APeQXpxcbYwa+06z/6Qk5Pqsv5V/zTXWQi2FhYipEsX1QAceP4MKRjttvxT1e1wNFwnYeX2gwobCGyeyauqDPtXDZ/Xfcjt3WQVqH6+7WJxau935lvjVM+SCwRRDGSwo0hJ4VEkudDy0DljTxwMlSuZj/WfOa08+GeL87e182W+RecgIAoIl8O/8D+g7LkQi5CQC+3AmdL1zF3d4TpQNd2wk/Mw9xheUqx4I9nC5UtZaGLZq38Jp2BYVLLAxOUdFqAi4bjXEX2vUgPfapFZw6CMZePIwDwhKeTOFDAsQh5qtttBVSmhCBDV4c/pjDpE3a/myTf443H0Mxgfy5s4k4yJV2etqvKu6XTqY81CygJbCyx9hoVklvjMTT69pk+odx+qzeFqdd0wfVtwSNc/EukN7ZCNBXv0iCIwOi39i4p04/0NehQjUkZzoyfglpv5iCbzCxjFnHEL9jzUtYWROBPOlE1/iD3U4"
            ebay.dev_id = 'H2I5D8KKY1LCG6GAGC27W16L2H246N'
	    ebay.app_id = 'DFKID2BFIR44L481M534QF6JZYRG2H'
	    ebay.cert   = 'E39434L9NZ6$CWAE17AL1-H7HT6597'
          end
	end 
	
	def ebay_configure_sand
          Ebay::Api.configure do |ebay|
            ebay.auth_token = "AgAAAA**AQAAAA**aAAAAA**pw8yRg**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4CnC5eLqASdj6x9nY+seQ**56wAAA**AAMAAA**Edq2sc8GZfCFzAgYacTZ/TLn1SbetlRjKoZvFMjQrvZg9IVSydtu2pvUNfZAs1+Rjms8bqBGyVMqJJV14BPZkxRiTInzmjwsYuc22dnwjBvKxF88Ex5l9rp3S+50y0buRTOzY0SA0l8MIeLu+9Xh8jtRp86/Rrn94XoIypbCIMArIbIsjYeXCl0qiljuEwjvLM1/MoIBrGNNWCHT3uJH8RGijHG/NO6BxheJhofk9dN6GqBuuoMErYNaF3MS3m5nYMa8odK1kaBF8yH3RAHkIc1DRpML/afs7mfg1CnJWUnFkhijks+/4TqgVbxxMwIizdEZ65nflvfGlkaKV2iKZZYlaiGWzSlS54z+02iNr703nE2pWBT9QGhyvNblIheqJZBLbuTHTL9wFv4ArZ3q3JptllP4PYBQYP62KG/sFo0fYBr9dgzDUq77CUAuXSSaLVLqAXCn5VTbTnoabU6NRiGZf/pyEuwgE6rPfPcHL89aomEqKPbYyEzXjWCbvloCyHkzH1y/pdU2VCwoe1aZPKBteWGEZXCpJo7c42N60gQbhldnfMtb5s4J1Q4UQbDplJf6S0qjjXgyBxpN3xOt2Dt/lvigSwD/MVp01KtMPCk32pp6mOW1vkQ2M7ww9hyyhiZGquwHewcLEmKJxMzNNRuhHlZNy1Rg2rqC21+O5FZLrGXt+cW6TE0cidfEBCQ3teLLoZPHNzabyzbVZ0WfFqFGmtqLWQuE9QUTqZZ93Ftx4jfhJwgdquvDEqdpVClN"
            ebay.dev_id = 'H2I5D8KKY1LCG6GAGC27W16L2H246N'
            ebay.app_id = 'DFKIA7K829FH1EA1I2185328489489'
            ebay.cert   = 'Q9G57A3LZCP$HEHHHRLRE-V63EK2A9'
            ebay.use_sandbox = true
          end
	end 
end


######################################################################################################

class BlogAccount < Account
        ############    Get Stuff   ############
	def fetch_feed
	   #TODO parse( posts( 10 ) )
        end
	
	def fetch_profile
	end  
	
	def fetch_items( count = 10, step = 10 )
	   updated = super( count )
	   return unless updated ## no more to update, return
	   sleep 1 ## prevent API DOS
	   fetch_items( count+step, step ) #checking if there are more..
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
	
	def raw_items( count = 10, blog_id = 1)
		api.call('metaWeblog.getRecentPosts', blog_id, username, password, count)
	end
	#alias posts raw_items
	
	private
	def api
	    @api ||= XMLRPC::Client.new2( host )
        end
	#alias blog api
	
	def fetch_items_init
	    fetch_items( 500, 100 ) #get 500 posting, increase by 100 if more..
        end
end	


