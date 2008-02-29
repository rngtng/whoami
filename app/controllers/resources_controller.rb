####################
#
# $LastChangedDate:2007-08-07 15:37:28 +0200 (Tue, 07 Aug 2007) $
# $Rev:94 $
# by $Author:bielohla $

#Controller for Resources. 100% RESTful. Create/Edit/Update not needed yet.
class ResourcesController < ApplicationController
   before_filter :login

   # show all resources. (Icon view)
   def index
     params[:from] = Time.parse( params[:from] ) if params[:from]
     params[:to]   = Time.parse( params[:to] )   if params[:to]
     
      feed_options = {
         :feed => {
            :title => "All resources",
            :link => resources_url
         },
         :item => {
            :title => :title,
            :pub_date => :time,
            :description => :text,
            :link => Proc.new { |post| resource_url( :id => post, :username => @user.login ) }
         }
      }

      @user.resources.with_complete do
         @min  = @user.resources.min_time
         @max  = @user.resources.max_time
         @resources = @user.resources.find_annotated_with( params )
      end
      @from = params[:from] ? params[:from] : @min
      @to   = params[:to]   ? params[:to]   : @max
      respond_to do |format|  #strange bug: fromat.html must be first in row in case format is not given!?
         format.html
         format.xml
         format.rss  { render_rss_feed_for @resources, feed_options }
         format.atom 
         format.ics  { render :text => to_ical( @resources ) }
         format.js   { render :partial => "partials/annotations_and_resources" }
      end
   end

   # show one resource (Detail view)
   def show
      @user.resources.with_complete do
         @resource = @user.resources.find( params[:id] )
      end
      @map = get_small_map( @resource )
   end

   # show the map (Map view)
   def map
      @user.resources.with_complete do
         @resources = @user.resources.find_annotated_with( params )
      end
      @map = get_map( @resources )
   end

   # show the timeline (Timeline view)
   def timeline
      @timeline = true
   end

   # show the cluster (Cluster view)
   def cluster
      @cluster = true
   end
   
   # show the iCal download page (iCal export)
   def ical
   end

   private
   # prepare map with resources
   def get_map(resources)
      map = GMap.new("large_map")
      map.control_init( :large_map => true, :map_type => true )
      ll = [0,0]
      info = ''
      to = [ll]
      i = 0
      color = [ "#ff0000", "#00ff00", "#0000ff"  ]
      resources.each do |resource|
         next if resource.geos.empty?
         geoannotation = resource.geos.first
         next if geoannotation.ll == ll
         #unless ll.empty?
         #info = "<div style='color:#000000'><img src='#{resource.thumbnail}' align='left'><b>#{resource.title}</b></div>"
         map.icon_global_init(GIcon.new(:image => resource.thumbnail, :icon_size => GSize.new(40,40), :icon_anchor => GPoint.new(7,7),:info_window_anchor => GPoint.new(9,2) ), "i#{resource.id}" )
         marker = GMarker.new( geoannotation.ll, :title => resource.title , :icon => Variable.new( "i#{resource.id}" ) ) #, :info_window => info )#, :icon => icon )
         map.overlay_init(marker)
         #end
         i += 30
         i = 0 if i > 255
         map.overlay_init( GPolyline.new( get_arrow([geoannotation.ll,ll]), "#00#{i.to_s(16)}#{(255-i).to_s(16)}", 3, 0.8) ) # color, width, opciy
         ll = geoannotation.ll
      end
      map.center_zoom_init( ll, 2 )
      return map
   end

   # prepare small map for detail resource view
   def get_small_map(resource)
      return nil if resource.geos.empty?
      map = GMap.new("small_map")
      map.control_init( :small_zoom => true, :map_type => true ) #:small_map => true, :map_type => true )
      ll = nil
      resource.geos.each do |geoannotation|
         info = "<div style='color:#000000'><img src='#{resource.thumbnail}' align='left'><b>#{resource.title}</b></div>"
         ll = geoannotation.ll
         marker = GMarker.new( ll, :title => resource.title, :info_window => info )#, :icon => icon )
         map.overlay_init(marker)
      end
      map.center_zoom_init(ll, 12 )
      return map
   end

   # draw arrow on map
   def get_arrow(line)
      return line
      from = line[0]
      to = line[1]
      y = to[0].to_i - from[0].to_i
      x = to[1].to_i - from[1].to_i
      phi = Math::PI/8
      x1 = x*Math.cos(phi) - y*Math.sin(phi)
      y1 = y*Math.cos(phi) + x*Math.sin(phi)
      x1 = x1 /8
      y1 = y1 /8
      phi = -Math::PI/8
      x2 = x*Math.cos(phi) - y*Math.sin(phi)
      y2 = y*Math.cos(phi) + x*Math.sin(phi)
      x2 = x2 /8
      y2 = y2 /8
      line << [ to[0].to_i-y2,to[1].to_i-x2] << [to[0], to[1]] << [ to[0].to_i-y1,to[1].to_i-x1]
   end

   #Returns an array of resources as iCal Format
   def to_ical( resources )
      calendar = Icalendar::Calendar.new
      calendar.custom_property("METHOD","PUBLISH")
      resources.each do |resource|
         calendar.add_event( resource.to_event )
      end
      calendar.to_ical
   end

end

