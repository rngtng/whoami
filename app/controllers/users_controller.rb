####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

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
