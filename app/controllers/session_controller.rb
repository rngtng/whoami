####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class SessionController < ApplicationController
   before_filter :login, :except => [ :new, :openid, :create, :create_openid ]

   def show
      redirect_to home_path
   end

   def new
      layout = ( request.xhr? ) ? false : "layouts/login"
      render( :layout => layout )
   end

   def openid
      layout = ( request.xhr? ) ? false : "layouts/login"
      render( :layout => layout )
   end

   def create_openid
      #if using_open_id?
      authenticate_with_open_id( params[:openid_url], :required => [ :nickname, :email ] ) do |result, identity_url, registration_attributes |
         return  unless result.successful?
         user = User.find_or_initialize_by_identity_url( identity_url )
         updated = user.assign_registration_attributes( { :login => 'nickname', :email => 'email' }, registration_attributes )
         user.save! if updated || user.new_record?
         self.current_user = user
         redirect_back_or_default( home_path )
      end
   end

   def create
      self.current_user = User.authenticate( params[:login], params[:password] )
      if logged_in? && params[:remember_me]
         self.current_user.remember_me
         cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
      end
      redirect_back_or_default( home_path )
   end

   #REST Functions missing: edit update

   def destroy
      self.current_user.forget_me if logged_in?
      cookies.delete :auth_token
      reset_session
      flash[:notice] = "You have been logged out."
      redirect_to home_path
   end

end

