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
