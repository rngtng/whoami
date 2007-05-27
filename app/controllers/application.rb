# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require_dependency 'Tag'

class ApplicationController < ActionController::Base
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_whoami2_session_id'
  
  filter_parameter_logging :password, :user
  filter_parameter_logging :password, :account
  
  private 
  def authorize
    @user = User.find_by_id(session[:user_id])      
    unless @user
      flash[:notice] = "Please log in" 
      redirect_to(:controller => "user", :action => "login", :include => 'accounts') 
    end 
  end 

end
