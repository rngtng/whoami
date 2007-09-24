####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class SessionController < ApplicationController
   layout "layouts/login"

   def show
      redirect_to home2_path()
   end

   def new
      return render( :layout => false ) if request.xhr?
   end

   def create
      if using_open_id?
         open_id_authentication(params[:openid_url])
      else
         password_authentication(params[:login], params[:password])
      end
   end

   def destroy
      self.current_user.forget_me if logged_in?
      cookies.delete :auth_token
      reset_session
      flash[:notice] = "You have been logged out."
      redirect_back_or_default( login_url )
   end

   protected
   def open_id_authentication(openid_url)
      begin
         authenticate_with_open_id(openid_url, :required => [:nickname, :email]) do |result, identity_url, registration|
            raise result.message unless result.successful?
            @user = User.find_or_initialize_by_identity_url(identity_url)
            if @user.new_record?
               @user.login = registration['nickname']
               @user.email = registration['email']
               @user.save(false) #bypass all validations!!
            end
            self.current_user = @user
            successful_login
         end
      rescue Exception => e
         failed_login e.message
      end
   end

   def password_authentication(login, password)
      self.current_user = User.authenticate(login, password)
      if logged_in?
         successful_login
      else
         failed_login
      end
   end

   def failed_login(message = "Authentication failed.")
      flash.now[:error] = message
      render :action => 'new'
   end

   def successful_login
      if params[:remember_me] == "1"
         self.current_user.remember_me
         cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
      end
      redirect_back_or_default( home2_url() )
      flash[:notice] = "Logged in successfully"
   end
end

