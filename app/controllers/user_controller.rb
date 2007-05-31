class UserController < ApplicationController
      before_filter :authorize, :except => :login
       
      def index 
	    @items = @user.valid_items.find_tagged_with( params )
	    #@items_month = @items.group_by { |i| i.time.beginning_of_month }
	    return render :action => :index unless request.xhr? 
	    render :partial => "item", :collection => @items
      end
      
      # just display the form and wait for user to  enter a name and password 
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
