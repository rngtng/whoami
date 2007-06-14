####################
#
# $LastChangedDate$
# $Rev$
# by $Author$

class ItemsController < ApplicationController
   before_filter :login

   exempt_from_layout :rxml

   def index
      @items = @user.valid_items.find_tagged_with( params )
      @min  = @user.valid_items.min_time.to_i / 1.day
      @max  = @user.valid_items.max_time.to_i / 1.day
      @from = params[:from] ? params[:from] : @min
      @to   = params[:to] ? params[:to] : @max
      #@items_month = @items.group_by { |i| i.time.beginning_of_month }
      respond_to do |format|
         format.js { render :partial => "partials/tags_and_items" }
         format.xml
         format.html
         format.ics {
            ical = Item.to_calendar( @items ).to_ical
            render :text => ical
         }
      end
   end

   def show
      @item = @user.valid_items.find( params[:id] )
      @map = get_map( @item )
   end

   def map
      @items = @user.valid_items.find_tagged_with( params )
      @map = get_map( @items.first )
   end


   def timeline
      @timeline = true
   end

   def ical
   end

   private
   def get_map(item)
      return nil if item.geos.empty?
      #@item = @user.items.find( params[:id] )
      map = GMap.new("small_map")
      map.control_init( :small_zoom => true, :map_type => true ) #:small_map => true, :map_type => true )
      #to = []
      ll = nil
      item.geos.each do |geotag|
         #next if item.geos.empty?
         #geotag = item.geos.first
         # icon = GIcon.new( :image => item.thumbnail, :icon_size => GSize.new(15,15) )
         info = "<div style='color:#000000'><img src='#{item.thumbnail}' align='left'><b>#{item.title}</b></div>"
         ll = geotag.ll
         marker = GMarker.new( ll, :title => item.title, :info_window => info )#, :icon => icon )
         map.overlay_init(marker)
         #to << geotag.ll
      end
      map.center_zoom_init(ll, 12 )
      #@map.overlay_init( GPolyline.new(to,"#ff0000",2,0.7) ) if to
      #@map.overlay_init( GMarker.new("Rue Clovis Paris",:info_window => "Rue Clovis Paris") )
      return map
   end
end

