class ItemsController < ApplicationController
      before_filter :login
	
      def index
	@items = @user.valid_items.find_tagged_with( params )
        #@items_month = @items.group_by { |i| i.time.beginning_of_month }
        return render :partial => "partials/tags_and_items", :collection => @items if request.xhr?      
      end

      def show
	@item = @user.items.find( params[:id] ) 
      end	
end
