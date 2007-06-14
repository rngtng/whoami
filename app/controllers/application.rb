####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base
   include AuthenticatedSystem

   # Pick a unique cookie name to distinguish our session data from others'
   session :session_key => '_whoami2_session_id'

   filter_parameter_logging :password, :user
   filter_parameter_logging :password, :account

   private
   def login
      login_from_cookie
      login_from_param unless logged_in?
      access_denied unless logged_in?
      @user = current_user
      @tag  = params[:tag] # ? params[:tag] : ''
      #@tag  = (params[:tag] && !params[:tag].empty?)  ? params[:tag] : nil
   end

   def login_from_param
      return true if logged_in?
      return false unless params[:auth]
      user = User.find_by_crypted_password(params[:auth])
      self.current_user = user if user
      #user = User.find_by_crypted_password(params[:auth])
      #self.current_user = user if user
   end

end

