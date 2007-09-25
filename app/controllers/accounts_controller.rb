####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class AccountsController < ApplicationController
   before_filter :login

   #a list of user's account
   def index
      redirect_to home_path( :username => @user.login )
   end

   def show
      @account = @user.accounts.find( params[:id] )
      redirect_to auth_account_path( @account ) and return if @account.requires_auth? and !@account.auth?
      params[:account_id] = params.delete( :id )
      @min  = @user.accounts.find( params[:account_id] ).valid_resources.min_time.to_i / 1.day
      @max  = @user.accounts.find( params[:account_id] ).valid_resources.max_time.to_i / 1.day
      @resources = @user.valid_resources.find_annotated_with( params )
      @from = params[:from] ? params[:from] : @min
      @to   = params[:to] ? params[:to] : @max
      respond_to do |format|
         format.html
         format.js { render :partial => "partials/annotations_and_resources" }
      end
   end

   def new
      @account = Account.factory params[:type]
      redirect_to auth_new_account_path( :type => params[:type] ) and return if @account.requires_auth?
   end

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

   def edit
      @account = @user.accounts.find( params[:id] )
   end

   def update
      @account = @user.accounts.find( params[:id] )
      if params[:account]
         @account.attributes = params[:account]
         redirect_to account_path( :id => @account, :username => @user.login ) and return if @account.save
      end
      flash[:error] = @account.errors.full_messages
      render :action => 'edit' #TODO redirect here??
   end

   def destroy
      @account = @user.accounts.find( params[:id] )
      @account.destroy
      redirect_to home_path( :username => @user.login )
   end

   ######custom REST actions:
   def auth
      @account = Account.factory params[:type]
      redirect_to auth_new_account_path( :type => params[:type] ) and return unless @account.requires_auth?
   end

   def auth_finish
      @account = Account.factory params[:type]
      redirect_to home_path and return unless @account
      @account.auth( params )
      @user.accounts << @account
      redirect_to account_path( :id => @account, :username => @user.login ) and return if @account.save
      #redirect_to auth_new_account_path( :type => params[:type] )
      render :action => 'auth'
   end

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

