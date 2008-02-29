####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

#Controller for Accounts. 100% RESTful, extended for auth, auth_finish and check_host
class AccountsController < ApplicationController
   before_filter :login

   #a list of user's account
   def index
      redirect_to home_path( :username => @user.login )
   end

   # icon view of one account
   def show
      params[:from] = Time.parse( params[:from] ) if params[:from]
      params[:to]   = Time.parse( params[:to] )   if params[:to]
      params[:account_id] = params.delete( :id ) unless params[:account_id]
      @account = @user.accounts.find( params[:account_id] )
      redirect_to auth_account_path( @account ) and return if @account.requires_auth? and !@account.auth?

      @account.resources.with_complete do
         @min  =  @account.resources.min_time
         @max  =  @account.resources.max_time
         @resources =  @account.resources.find_annotated_with( params )
      end

      @from = params[:from] ? params[:from] : @min
      @to   = params[:to]   ? params[:to]   : @max
      respond_to do |format|
         format.html
         format.js { render :partial => "partials/annotations_and_resources" }
      end
   end

   # new account mask
   def new
      @account = Account.factory params[:type]
      redirect_to auth_new_account_path( :type => params[:type] ) and return if @account.requires_auth?
   end

   # create new account
   def create
      begin
         @account = Account.factory params[:type]
         if params[:account]
            @account.attributes = params[:account]
            @user.accounts << @account
            redirect_to account_path( :id => @account, :username => @user.login ) and return if @account.save
         end
         flash[:error] = @account.errors.full_messages
         render :action => 'new' #TODO redirect here??
         #rescue
         #  redirect_to home_path()
      end
      #redirect_to new_account_path( :type => params[:type] )
   end

   # edit account mask
   def edit
      @account = @user.accounts.find( params[:id] )
   end

   # update account
   def update
      @account = @user.accounts.find( params[:id] )
      if params[:account]
         @account.attributes = params[:account]
         redirect_to account_path( :id => @account, :username => @user.login ) and return if @account.save
      end
      flash[:error] = @account.errors.full_messages
      render :action => 'edit' #TODO redirect here??
   end

   #delete account
   def destroy
      @account = @user.accounts.find( params[:id] )
      @account.destroy
      redirect_to home_path( :username => @user.login )
   end

   ######custom REST actions:
   # display page to redirect to external auth page
   def auth
      @account = Account.factory params[:type]
      redirect_to auth_new_account_path( :type => params[:type] ) and return unless @account.requires_auth?
   end

   # entry point after sucessful authorized WhoAmI to use the account
   def auth_finish
      @account = Account.factory params[:type]
      redirect_to home_path and return unless @account
      @account.auth( params )
      @user.accounts << @account
      redirect_to account_path( :id => @account, :username => @user.login ) and return if @account.save
      #redirect_to auth_new_account_path( :type => params[:type] )
      render :action => 'auth'
   end

   # AJAX helper to check if URL is valid / contains a feed
   def check_host
      @account = Account.factory params[:type]
      begin
         @url =  UrlChecker.check_url( params[:host] )
      rescue Exception => e
         @e = e
      end
      render( :layout => false )
   end
end

