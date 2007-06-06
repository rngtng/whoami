####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class AccountsController < ApplicationController
   before_filter :login

   #a list of user's account
   def index
      redirect_to home_path
   end

   def show
      @account = @user.accounts.find( params[:id] )
      redirect_to auth_account_path( @account.id ) and return if @account.requires_auth? and !@account.auth?
      params[:account_id] = params.delete( :id )
      @items = @user.valid_items.find_tagged_with( params )
      return render( :partial => "partials/tags_and_items" ) if request.xhr?
   end

   def new
      @account = Account.factory params[:name]
      redirect_to auth_new_account_path( :name => params[:name] ) and return if @account.requires_auth?
   end

   def create
      @account = Account.factory params[:name]
      if params[:account]
         @account.attributes = params[:account]
         @user.accounts << @account
         redirect_to account_path( @account ) and return if @account.save
      end
      flash[:error] = @account.errors.full_messages
      render :action => 'new' #TODO redirect here??
      #redirect_to new_account_path( :name => params[:name] )
   end

   def edit
      @account = @user.accounts.find( params[:id] )
   end

   def update
      @account = @user.accounts.find( params[:id] )
      if params[:account]
         @account.attributes = params[:account]
         redirect_to account_path( @account ) and return if @account.save
      end
      flash[:error] = @account.errors.full_messages
      render :action => 'edit' #TODO redirect here??
   end


   def destroy
      @account = @user.accounts.find( params[:id] )
      @account.destroy
      redirect_to home_path
   end

   ######custom REST actions:
   def auth
      @account = Account.factory params[:name]
      redirect_to auth_new_account_path( :name => params[:name] ) and return unless @account.requires_auth?
      @account.username = @user.login
      @user.accounts << @account
      @account.save
   end

   def auth_finish
      @account = @user.accounts.find_by_username( @user.login )
      redirect_to home_path and return unless @account
      @account.auth( params )
      @account.save
      redirect_to account_path( @account.id )
   end
end

