#!/usr/bin/env ruby

#You might want to change this
ENV["RAILS_ENV"] ||= "development"

require File.dirname(__FILE__) + "/../../config/environment"

$running = true;
Signal.trap("TERM") do 
  $running = false
end

while($running) do
  # Replace this with your code
  f = Account.find_to_update( 'Blog') 
  ActiveRecord::Base.logger << "Updateing Account #{f.type} by #{f.user.name} at #{Time.now}.\n"
  f.daemon_fetch_items
  sleep f.daemon_sleep_time
end