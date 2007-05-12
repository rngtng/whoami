#require 'activemessaging/processor'

class AccountController < ApplicationController
      #include ActiveMessaging::MessageSender
      
      #publishes_to :item_update
      
      before_filter :authorize
      before_filter :set, :except => [ :add, :auth_finish]	
	
      def index
	     redirect_to :action => "auth", :id => @account.id and return if @account.requires_auth? and !@account.auth?     
	     @items = @account.get_items( :order => 'time DESC' )
      end
      
      def tags
        @tags = Item.tag_counts
      end
      
      def add
         @account = Account.factory params[:id]
         @user.accounts << @account  
	 redirect_to :action => "auth", :id => @account.id and return if @account.requires_auth?  
         redirect_to :action => "edit", :id => @account.id
      end
      
      def auth
	   @account.username = "unknown"
	   @account.save   
	   redirect_to :action => "edit", :id => @account.id and return if @account.auth?
      end
      
      def edit
          if params[:account]
            @account.attributes = params[:account] 
            redirect_to :action => "index" and return if @account.save
          end  
      end
      
      def auth_finish
	      @account = @user.accounts.find_by_username( "unknown" )
	      redirect_to :controller => "user" and return unless @account
	      @account.auth( params )
	      @account.save
              redirect_to :action => "index", :id => @account.id
      end
      
      def delete
              @account.destroy
              redirect_to :controller => "user", :action => "index"
      end
      
      #Ajax Call #TODO combine with index??
      def get_items
	 render :partial => "item", :collection => @account.get_items
      end
      
      private 
      def set
          redirect_to(:controller => "user", :action => "index")  unless params[:id] 
          @account = @user.accounts.find_by_id( params[:id] )
      end
      
end
