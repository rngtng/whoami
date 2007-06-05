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
	access_denied unless logged_in?
	@user = current_user
  end
      
end
