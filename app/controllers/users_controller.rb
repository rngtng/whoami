class UsersController < ApplicationController
  before_filter :login, :except => [ :new, :create ]
  layout "layouts/login"
  
  def new
    @user = User.new
    return render( :layout => false ) if request.xhr? 
  end

  def create
    @user = User.new(params[:user])
    @user.activate!
    #@user.save!
    self.current_user = @user
    redirect_back_or_default('/')
  rescue Exception => e 
    flash[:notice] = e.message 
    render( :action => 'new' )
  end

  def activate
    self.current_user = User.find_by_activation_code(params[:activation_code])
    if logged_in? && !current_user.activated?
      current_user.activate
    end
    redirect_back_or_default('/')
  end
end

    # # just display the form and wait for user to  enter a name and password 
    # def openid
    #    return render :layout => false if request.xhr? 
    #    render :layout => "layouts/login" 	      
    # end
    # 
    # def login 
    #    session[:user_id] = nil 
    #    if request.post? 
    #      user = User.authenticate(params[:name], params[:password]) 
    #      if user 
    #        session[:user_id] = user.id 
    #        redirect_to(:action => "index")
    #        return
    #      else 
    #        flash[:notice] = "Invalid user/password combination"
    #      end 
    #    end
	# return render :layout => false if request.xhr? 
    #    render :layout => "layouts/login" 
    # end 
    # 
    # def logout 
    #     session[:user_id] = nil 
    #     flash[:notice] = "Logged out" 
    #     redirect_to(:action => "login") 
    # end 
    # 
    # def create
	#  @user = User.new()    
	#  if params[:user]
    #         @user.attributes = params[:user]
	#      begin
	#         @user.save!
	#         session[:user_id] = @user.id 
    #            redirect_to :action => "index"
	#	 return
	#      rescue Exception => e 
    #            flash[:notice] = e.message 
    #         end
    #     end 
	#  return render :layout => false if request.xhr? 
	#  render :layout => "layouts/login" 
    # end	      
	      
	      
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
#end
