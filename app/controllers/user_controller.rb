class UserController < ApplicationController
      before_filter :authorize, :except => :login
       
      def index 
	    @items = @user.valid_items #.find( :tag)
	    @tags = @user.notes
	    render_index   
      end
      
      def tags
	   params[:tag] = params[:id] if params[:id]   
	   redirect_to( :action => "index" ) and return unless params[:tag]
	   @items = get_items :tag => params[:tag]
	   @tags = Item.tag_counts( :conditions => [ "items.id IN (?) ", @items.map( &:id ) ] ) #, :order => "count DESC" )
	   render_index
      end
      
      def week
      end

      def year      
	end
	      
      def day
	      date()
      end
      
      def date( offset = 1.day, date = Time.now )
	     date_from = date - offset
	     date_to = date
	  @items = get_items :date_from => date_from, :date_to => date_to    
	  render_index    
      end	     
	      
      
      def render_index
	    @items_month = @items.group_by { |i| i.time.beginning_of_month }
	    return render :action => :index unless request.xhr? 
	    #render :partial => "tag", :collection => @tags
	    render :partial => "item", :collection => @items
      end
           
      # just display the form and wait for user to 
      # enter a name and password 
      def login 
         session[:user_id] = nil 
         if request.post? 
           user = User.authenticate(params[:name], params[:password]) 
           if user 
             session[:user_id] = user.id 
             redirect_to(:action => "index")
             return
           else 
             flash[:notice] = "Invalid user/password combination"
           end 
         end 
         render(:layout => "layouts/login")
      end 
      
      def logout 
          session[:user_id] = nil 
          flash[:notice] = "Logged out" 
          redirect_to(:action => "login") 
      end 
      
      private
    #  @user = User.new(params[:user]) 
    #  if request.post? and @user.save 
    #    flash.now[:notice] = "User #{@user.name} created" 
    #    @user = User.new 
    #  end
    #end 
    
    # . . . 
    #def delete
    #  if request.post? 
    #    user = User.find(params[:id]) 
    #    begin 
    #      user.destroy 
    #      flash[:notice] = "User #{user.name} deleted" 
    #    rescue Exception => e 
    #      flash[:notice] = e.message 
    #    end 
    #  end 
    #  redirect_to(:action => :list_users) 
    #end 
end
