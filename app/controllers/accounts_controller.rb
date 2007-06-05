class AccountsController < ApplicationController
      before_filter :login
      
      #a list of user's account
      def index
      end
      
      def show
	 @account = @user.accounts.find( params[:id] )
	 redirect_to auth_account_path( @account.id ) and return if @account.requires_auth? and !@account.auth?
	 params[:account_id] = params.delete( :id )
         @items = @user.valid_items.find_tagged_with( params )
	 return render( :partial => "partials/tags_and_items" ) if request.xhr?   
      end      
	      
      def create
         @account = Account.factory params[:name]
         @user.accounts << @account  
	 redirect_to auth_account_path( @account.id ) and return if @account.requires_auth?  
         redirect_to edit_account_path( @account.id )
      end
      
      def edit
	  @account = @user.accounts.find( params[:id] )
      end
     
      def update
	  @account = @user.accounts.find( params[:id] )
          if params[:account]
            @account.attributes = params[:account] 
            redirect_to account_path( @account.id ) and return if @account.save
          end  
      end
      
      
      def destroy
	      @account = @user.accounts.find( params[:id] ) 
              @account.destroy
              redirect_to home_path
      end

      ######custom REST actions:
      def auth
	   @account = @user.accounts.find( params[:id] )   
	   @account.username = "unknown"
	   @account.save   
	   redirect_to edit_acount_path( @account.id ) and return if @account.auth?
      end
      
      def auth_finish
	      @account = @user.accounts.find_by_username( "unknown" )
	      redirect_to home_path and return unless @account
	      @account.auth( params )
	      @account.save
              redirect_to account_path( @account.id )
      end
end
