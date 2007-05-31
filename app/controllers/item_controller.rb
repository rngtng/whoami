class ItemController < ApplicationController
	before_filter :authorize
	
	def index
		@item = @user.items.find( params[:id] )
	end	
end
