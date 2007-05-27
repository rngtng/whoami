class ItemController < ApplicationController
	before_filter :authorize
	
	def index
		@item = Item.find( params[:id] )
		#@tags = @item.tags
	end	
end
