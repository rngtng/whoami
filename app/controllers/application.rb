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
      login_from_param if params[:auth]
      login_required
      @user = current_user
      @annotation  = params[:annotation] # ? params[:annotation] : ''
      #@annotation  = (params[:annotation] && !params[:annotation].empty?)  ? params[:annotation] : nil
   end
   
   def login_from_param 
      return true if logged_in?
      user = User.find_by_crypted_password(params[:auth] )
      self.current_user = user if user
   end
end

