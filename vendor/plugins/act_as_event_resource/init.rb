# Include hook code here

require "act_as_event_resource"

class ActiveRecord::Base
  extend ActAsEventResource 	
end