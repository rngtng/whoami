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
      respond_to do |format|  #strange bug: fromat.html must be first in row in case format is not given!?
         format.html
         format.xml
         format.ics {
            ical = Item.to_calendar( @items ).to_ical
            render :text => ical
         }
         format.js { render :partial => "partials/tags_and_items" }
      end
   end

   def show
      @item = @user.valid_items.find( params[:id] )
      @map = get_small_map( @item )
   end

   def map
      @items = @user.valid_items.find_tagged_with( params )
      @map = get_map( @items )
   end


   def timeline
      @timeline = true
   end

   def ical
   end

   private
   def get_map(items)
      map = GMap.new("large_map")
      map.control_init( :large_map => true, :map_type => true )
      ll = []
      info = ''
      to = [ll]
      i = 0
      color = [ "#ff0000", "#00ff00" ]
      items.each do |item|
         next if item.geos.empty?
         geotag = item.geos.first
         next if geotag.ll == ll
         #unless ll.empty?
         #info = "<div style='color:#000000'><img src='#{item.thumbnail}' align='left'><b>#{item.title}</b></div>"
         map.icon_global_init(GIcon.new(:image => item.thumbnail, :icon_size => GSize.new(40,40), :icon_anchor => GPoint.new(7,7),:info_window_anchor => GPoint.new(9,2) ), "i#{item.id}" )
         marker = GMarker.new( geotag.ll, :title => item.title , :icon => Variable.new( "i#{item.id}" ) ) #, :info_window => info )#, :icon => icon )
         map.overlay_init(marker)
         #end
         i = (-i) + 1
         map.overlay_init( GPolyline.new( get_arrow([geotag.ll,ll]), color[i],2,0.7) )
         ll = geotag.ll
      end
      map.center_zoom_init(ll, 2 )
      return map
   end

   def get_small_map(item)
      return nil if item.geos.empty?
      map = GMap.new("small_map")
      map.control_init( :small_zoom => true, :map_type => true ) #:small_map => true, :map_type => true )
      ll = nil
      item.geos.each do |geotag|
         info = "<div style='color:#000000'><img src='#{item.thumbnail}' align='left'><b>#{item.title}</b></div>"
         ll = geotag.ll
         marker = GMarker.new( ll, :title => item.title, :info_window => info )#, :icon => icon )
         map.overlay_init(marker)
      end
      map.center_zoom_init(ll, 12 )
      return map
   end

   def get_arrow(line)
      from = line[0]
      to = line[1]
      y = to[0].to_i - from[0].to_i
      x = to[1].to_i - from[1].to_i
      phi = Math::PI/8
      x1 = x*Math.cos(phi) - y*Math.sin(phi)
      y1 = y*Math.cos(phi) + x*Math.sin(phi)
      x1 = x1 /5
      y1 = y1 /5
      phi = -Math::PI/8
      x2 = x*Math.cos(phi) - y*Math.sin(phi)
      y2 = y*Math.cos(phi) + x*Math.sin(phi)
      x2 = x2 /5
      y2 = y2 /5
      line << [ to[0].to_i-y2,to[1].to_i-x2] << [to[0], to[1]] << [ to[0].to_i-y1,to[1].to_i-x1]
   end
end

