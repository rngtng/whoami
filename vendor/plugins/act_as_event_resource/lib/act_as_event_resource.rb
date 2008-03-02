# ActAsEventResource
module ActAsEventResource

   def act_as_event_resource
      # Returns resource as iCal event
      define_method "to_event" do
         event = Icalendar::Event.new
         event.dtstart     = time.strftime("%Y%m%dT%H%M%S")
         event.summary     = title
         event.url         = url
         event.description = text
         event.categories  = [type]
         #event.geo         = Icalendar::Geo.new( geos.first.lat, geos.first.lng ) unless geos.empty?
         #sevent.location    = locations.map!( &:name).join(',' )

         #event.related_to
         #event contacts
         #event.klass = "PUBLIC"
         #event.attachment
         event
      end
   end

end
