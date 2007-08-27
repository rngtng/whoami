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
      @user.save!
      self.current_user = @user
      redirect_back_or_default( home_url )
   rescue Exception => e
      flash[:notice] = e.message
      render( :action => 'new' )
   end
end
